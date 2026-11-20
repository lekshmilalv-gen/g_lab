import 'api_client.dart';

/// Sign-in state backed by the backend JWT authentication endpoint.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  String? accessToken;
  String? refreshToken;
  String? username;

  bool get isSignedIn => accessToken != null;

  /// Authenticates with the backend and stores the returned JWT tokens.
  Future<void> login(String username, String password) async {
    try {
      final response = await ApiClient.instance.postJson(
        '/api/auth/login/',
        {'username': username, 'password': password},
        authenticated: false,
      );
      final access = response['access'] ?? response['access_token'];
      final refresh = response['refresh'] ?? response['refresh_token'];
      if (access is! String || access.isEmpty) {
        throw const AuthException('The server did not return an access token.');
      }
      accessToken = access;
      refreshToken = refresh is String ? refresh : null;
    } on ApiException catch (e) {
      throw AuthException(e.message);
    } on AuthException {
      rethrow;
    } on Exception {
      throw AuthException(
        'Could not reach ${ApiClient.baseUrl}. Make sure the backend '
        'is running and reachable from this device.',
      );
    }
    this.username = username;
  }

  void logout() {
    accessToken = null;
    refreshToken = null;
    username = null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
