import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'api_client.dart';
import 'auth_service.dart';

/// WebSocket signaling and remote WebRTC video for one patient session.
///
/// The backend only relays SDP and ICE. Video travels directly from the Jetson
/// to the Flutter device after the peer connection is established.
class LiveVideoSession extends ChangeNotifier {
  LiveVideoSession() : renderers = List.generate(3, (_) => RTCVideoRenderer());

  final List<RTCVideoRenderer> renderers;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final Map<String, int> _trackSlots = {};
  final List<MediaStream> _fallbackStreams = [];

  WebSocket? _socket;
  RTCPeerConnection? _peer;
  StreamSubscription<dynamic>? _socketSubscription;
  Future<void>? _connectOperation;
  Future<void> _messageQueue = Future<void>.value();
  dynamic _sessionId;
  String? _patientId;
  bool _sessionStarted = false;
  bool _renderersInitialized = false;
  bool _disposed = false;
  bool _closing = false;
  String _status = 'Connecting to video service';
  String? _error;

  String get status => _error ?? _status;
  int get activeFeeds => renderers.where((renderer) => renderer.srcObject != null).length;
  bool get hasVideo => activeFeeds > 0;
  bool get isSignalingReady => _socket != null && !_closing;

  Future<void> connect() {
    if (isSignalingReady) return Future<void>.value();
    final pending = _connectOperation;
    if (pending != null) return pending;
    final operation = _connect();
    _connectOperation = operation;
    return operation.whenComplete(() {
      if (identical(_connectOperation, operation)) _connectOperation = null;
    });
  }

  Future<void> _connect() async {
    _setStatus('Connecting to video service');
    try {
      if (!_renderersInitialized) {
        for (final renderer in renderers) {
          await renderer.initialize();
        }
        _renderersInitialized = true;
      }

      final base = Uri.parse(ApiClient.baseUrl);
      final token = AuthService.instance.accessToken ?? 'no-auth-placeholder';
      final uri = base.replace(
        scheme: base.scheme == 'https' ? 'wss' : 'ws',
        host: base.host == '0.0.0.0' ? '127.0.0.1' : base.host,
        path: '/ws/app/',
        queryParameters: {'token': token},
      );
      final socket = await WebSocket.connect(uri.toString()).timeout(
        const Duration(seconds: 12),
      );
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _socketSubscription = socket.listen(
        _onSocketData,
        onDone: _onSocketDone,
        onError: _onSocketError,
        cancelOnError: false,
      );
      _setStatus('Connected · waiting to start');
    } on Object catch (error) {
      _setError('Video signaling failed: $error');
    }
  }

  Future<void> startSession(String patientId) async {
    await connect();
    if (!isSignalingReady) {
      throw StateError(_error ?? 'Video signaling is not connected.');
    }
    await _closePeer();
    _sessionStarted = true;
    _sessionId = null;
    _patientId = patientId;
    try {
      await _send({'type': 'start_session', 'patient_id': patientId});
      _setStatus('Session requested · waiting for camera offer');
    } on Object catch (error) {
      _sessionStarted = false;
      _setError('Could not start video session: $error');
      rethrow;
    }
  }

  Future<void> stopSession() async {
    Object? stopError;
    if (_sessionStarted && isSignalingReady) {
      try {
        await _send({
          'type': 'stop_session',
          if (_patientId != null) 'patient_id': _patientId,
          if (_sessionId != null) 'session_id': _sessionId,
        });
      } on Object catch (error) {
        stopError = error;
      }
    }
    _sessionStarted = false;
    await _closePeer();
    if (stopError != null) {
      _setError('Could not stop video session: $stopError');
    } else {
      _setStatus(isSignalingReady ? 'Connected' : 'Disconnected');
    }
  }

  void _onSocketData(dynamic raw) {
    if (raw is! String) return;
    _messageQueue = _messageQueue
        .then((_) => _handleMessage(raw))
        .catchError((Object error) {
          _setError('Video negotiation failed: $error');
        });
  }

  Future<void> _handleMessage(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final message = Map<String, dynamic>.from(decoded);
    switch (message['type']) {
      case 'sdp_offer':
        await _handleOffer(message);
        break;
      case 'ice_candidate':
        await _handleRemoteCandidate(message);
        break;
      case 'error':
        _setError('Video service: ${message['detail'] ?? 'request failed'}');
        break;
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> message) async {
    final sdp = message['sdp'];
    if (sdp is! String || sdp.isEmpty) {
      throw const FormatException('The camera offer did not include SDP.');
    }
    await _closePeer();
    _sessionId = message['session_id'];
    _pendingRemoteCandidates.clear();
    _trackSlots.clear();

    final peer = await createPeerConnection({
      'sdpSemantics': 'unified-plan',
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    _peer = peer;
    peer.onTrack = (event) => unawaited(_attachTrack(event));
    peer.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      unawaited(
        _send({
          'type': 'ice_candidate',
          'session_id': _sessionId,
          'candidate': value,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }).catchError((Object error) {
          _setError('Could not send ICE candidate: $error');
        }),
      );
    };
    peer.onIceConnectionState = (state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _setStatus('Live video connected');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _setError('Video connection failed. Check the Jetson network route.');
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _setStatus('Video connection interrupted');
          break;
        default:
          _setStatus('Negotiating live video');
          break;
      }
    };

    await peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    for (final candidate in _pendingRemoteCandidates) {
      await peer.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    final localDescription = await peer.getLocalDescription();
    if (localDescription?.sdp == null) {
      throw const FormatException('Flutter could not create an SDP answer.');
    }
    await _send({
      'type': 'sdp_answer',
      'session_id': _sessionId,
      'sdp': localDescription!.sdp,
    });
    _setStatus('Answer sent · connecting video');
  }

  Future<void> _attachTrack(RTCTrackEvent event) async {
    if (event.track.kind != 'video') return;
    final trackId = event.track.id ?? 'track-${_trackSlots.length}';
    int? slot = _trackSlots[trackId];
    if (slot == null) {
      for (var index = 0; index < renderers.length; index++) {
        if (!_trackSlots.values.contains(index)) {
          slot = index;
          break;
        }
      }
    }
    if (slot == null) return;
    _trackSlots[trackId] = slot;
    final MediaStream stream;
    if (event.streams.isNotEmpty) {
      stream = event.streams.first;
    } else {
      stream = await createLocalMediaStream('remote-$trackId');
      await stream.addTrack(event.track);
      _fallbackStreams.add(stream);
    }
    await renderers[slot].setSrcObject(
      stream: stream,
      trackId: event.track.id,
    );
    _setStatus('Live video connected');
  }

  Future<void> _handleRemoteCandidate(Map<String, dynamic> message) async {
    final value = message['candidate'];
    if (value is! String || value.isEmpty) return;
    final lineIndex = message['sdpMLineIndex'];
    final candidate = RTCIceCandidate(
      value,
      message['sdpMid'] as String?,
      lineIndex is num ? lineIndex.toInt() : null,
    );
    final peer = _peer;
    if (peer == null || await peer.getRemoteDescription() == null) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    await peer.addCandidate(candidate);
  }

  Future<void> _send(Map<String, dynamic> message) async {
    final socket = _socket;
    if (socket == null || _closing) throw StateError('Signaling socket is closed.');
    socket.add(jsonEncode(message));
  }

  void _onSocketDone() {
    _socket = null;
    if (!_disposed && !_closing) _setStatus('Video signaling disconnected');
  }

  void _onSocketError(Object error) {
    _socket = null;
    if (!_disposed) _setError('Video signaling disconnected: $error');
  }

  Future<void> _closePeer() async {
    final peer = _peer;
    _peer = null;
    if (peer != null) await peer.close();
    for (final renderer in renderers) {
      if (renderer.srcObject != null) {
        await renderer.setSrcObject(stream: null);
      }
    }
    for (final stream in _fallbackStreams) {
      await stream.dispose();
    }
    _fallbackStreams.clear();
    _trackSlots.clear();
    _pendingRemoteCandidates.clear();
  }

  void _setStatus(String value) {
    if (_disposed) return;
    _error = null;
    _status = value;
    notifyListeners();
  }

  void _setError(String value) {
    if (_disposed) return;
    _error = value;
    _status = 'Video unavailable';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    _closing = true;
    final socket = _socket;
    if (_sessionStarted && socket != null) {
      try {
        socket.add(jsonEncode({
          'type': 'stop_session',
          if (_patientId != null) 'patient_id': _patientId,
          if (_sessionId != null) 'session_id': _sessionId,
        }));
      } catch (_) {}
    }
    _sessionStarted = false;
    await _socketSubscription?.cancel();
    await _closePeer();
    await socket?.close();
    if (_renderersInitialized) {
      for (final renderer in renderers) {
        await renderer.dispose();
      }
      _renderersInitialized = false;
    }
  }
}
