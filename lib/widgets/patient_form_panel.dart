import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/doctor.dart';
import '../models/patient.dart';
import '../services/auth_service.dart';
import '../services/doctor_service.dart';
import '../services/patient_service.dart';

/// Slides the Create New Patient panel in from the right over a blurred
/// background. Pass [patient] to edit an existing patient instead.
///
/// Resolves to the saved patient, or `null` if the panel was closed.
Future<Patient?> showPatientFormPanel(
  BuildContext context, {
  Patient? patient,
}) {
  return showGeneralDialog<Patient>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Patient form',
    barrierColor: Colors.transparent, // the blur layer below draws the dim
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _PatientFormPanel(patient: patient),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final Animation<Offset> slide =
          Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );
      return AnimatedBuilder(
        animation: fade,
        builder: (context, _) => BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * fade.value,
            sigmaY: 8 * fade.value,
          ),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.45 * fade.value),
            child: Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(position: slide, child: child),
            ),
          ),
        ),
      );
    },
  );
}

class _PatientFormPanel extends StatefulWidget {
  const _PatientFormPanel({this.patient});

  final Patient? patient;

  @override
  State<_PatientFormPanel> createState() => _PatientFormPanelState();
}

class _PatientFormPanelState extends State<_PatientFormPanel> {
  static const Color _gold = Color(0xFFE7CA55);
  static const Color _goldMuted = Color(0xFFA38B45);
  static const Color _panelBg = Color(0xFF1C1B18);
  static const Color _hint = Color(0xFF8A8A8A);
  static const List<String> _genders = ['Male', 'Female', 'Other'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _doctor;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _patientId;
  late final TextEditingController _phone;
  late final TextEditingController _remark;
  late final TextEditingController _dobText;
  final List<Doctor> _doctors = [];
  DateTime? _dob;
  String? _gender;
  String? _selectedDoctorId;
  String? _photoPath;
  String? _photoError;
  bool _capturing = false;
  bool _saving = false;
  bool _loadingDoctors = false;
  bool _restoreAutoRotationOnDispose = false;

  bool get _isEdit => widget.patient != null;

  @override
  void initState() {
    super.initState();
    final Patient? p = widget.patient;
    _name = TextEditingController(text: p?.name);
    _doctor = TextEditingController(text: p?.doctor);
    _height = TextEditingController(text: p?.height);
    _weight = TextEditingController(text: p?.weight);
    _patientId = TextEditingController(text: p?.patientId);
    _phone = TextEditingController(text: p?.phone);
    _remark = TextEditingController(text: p?.remark);
    _dob = p?.dob;
    _dobText = TextEditingController(text: _formatDate(_dob));
    _gender = p?.gender;
    _selectedDoctorId = p?.doctorId;
    _photoPath = p?.photoPath;
    _loadingDoctors = AuthService.instance.isSignedIn;
    if (_loadingDoctors) _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    if (!AuthService.instance.isSignedIn) return;
    try {
      final doctors = await DoctorService.instance.fetchAll();
      if (!mounted) return;
      setState(() {
        _doctors
          ..clear()
          ..addAll(doctors);
        if (_selectedDoctorId != null) {
          final selected = _doctors.where(
            (doctor) => doctor.doctorId == _selectedDoctorId,
          );
          if (selected.isNotEmpty) _doctor.text = selected.first.name;
        }
      });
    } on DoctorServiceException {
      // Leave the form usable when the doctor directory is unavailable.
    } finally {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  @override
  void dispose() {
    if (_restoreAutoRotationOnDispose) {
      unawaited(_restoreAutoRotation());
    }
    for (final c in [
      _name,
      _doctor,
      _height,
      _weight,
      _patientId,
      _phone,
      _remark,
      _dobText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _formatDate(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDob() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _gold,
            onPrimary: Colors.black,
            surface: _panelBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobText.text = _formatDate(picked);
      });
    }
  }

  /// Opens the device camera and keeps the captured photo for this patient.
  Future<void> _capturePhoto() async {
    if (_capturing) return;
    final Orientation formOrientation = MediaQuery.orientationOf(context);
    final List<DeviceOrientation> preferredOrientations =
        formOrientation == Orientation.portrait
        ? const [DeviceOrientation.portraitUp]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
    setState(() {
      _capturing = true;
      _photoError = null;
    });
    try {
      await SystemChrome.setPreferredOrientations(preferredOrientations);
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (photo != null) {
        _restoreAutoRotationOnDispose = true;
        setState(() => _photoPath = photo.path);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(
        () => _photoError = e.code == 'camera_access_denied'
            ? 'Camera permission denied. Allow it in Settings.'
            : 'Could not open the camera.',
      );
    } finally {
      if (!_restoreAutoRotationOnDispose) await _restoreAutoRotation();
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _restoreAutoRotation() async {
    try {
      await SystemChrome.setPreferredOrientations(const []);
    } on Object {
      // Keep the form usable even if the platform cannot restore orientation.
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final PatientStore store = PatientStore.instance;
    final String id = _patientId.text.trim().isEmpty
        ? store.nextPatientId()
        : _patientId.text.trim();

    final Patient saved = Patient(
      patientId: id,
      name: _name.text.trim(),
      dob: _dob,
      doctor: _doctor.text.trim(),
      doctorId: _selectedDoctorId,
      height: _height.text.trim(),
      weight: _weight.text.trim(),
      gender: _gender,
      phone: _phone.text.trim(),
      remark: _remark.text.trim(),
      photoPath: _photoPath,
      // Fields the form doesn't edit are carried over from the original.
      serverId: widget.patient?.serverId,
      age: widget.patient?.age,
      email: widget.patient?.email ?? '',
      address: widget.patient?.address ?? '',
      diagnosis: widget.patient?.diagnosis ?? '',
      isActive: widget.patient?.isActive ?? true,
      sessionCount: widget.patient?.sessionCount ?? 0,
      lastSessionAt: widget.patient?.lastSessionAt,
    );
    if (_isEdit) {
      final Patient original = widget.patient!;
      if (original.serverId == null) {
        store.replace(original, saved);
        Navigator.of(context).pop(saved);
        return;
      }

      setState(() => _saving = true);
      try {
        final Patient updated = await PatientService.instance.update(
          original.patientId,
          saved,
        );
        if (!mounted) return;
        store.replace(original, updated);
        await store.reload();
        if (!store.patients.any(
          (patient) =>
              (updated.serverId != null &&
                  patient.serverId == updated.serverId) ||
              patient.patientId == updated.patientId,
        )) {
          store.add(updated);
        }
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      } on PatientServiceException catch (e) {
        _showSaveError(e.message);
      }
      return;
    }

    if (!AuthService.instance.isSignedIn) {
      store.add(saved);
      Navigator.of(context).pop(saved);
      return;
    }

    setState(() => _saving = true);
    try {
      final Patient created = await PatientService.instance.create(saved);
      if (!mounted) return;
      store.add(created);
      await store.reload();
      // Keep the successful POST result visible if the follow-up list request
      // fails or has not indexed the new record yet.
      if (!store.patients.any(
        (patient) =>
            (created.serverId != null &&
                patient.serverId == created.serverId) ||
            patient.patientId == created.patientId,
      )) {
        store.add(created);
      }
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on PatientServiceException catch (e) {
      _showSaveError(e.message);
    }
  }

  void _showSaveError(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not save patient: $message')));
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    // Sizes follow the design (panel drawn at 652px tall), so the whole form
    // fits the screen height like the reference; it scrolls only when the
    // keyboard is open or the screen is very short.
    // The form is a side panel on wide screens and fills the viewport on
    // phones. Keeping the old 360px minimum made it overflow narrow devices.
    final double u = (screen.height / 652).clamp(0.6, 2.0);
    final double panelWidth = screen.width < 600
        ? screen.width
        : (screen.width * 0.36).clamp(360.0, 640.0);
    final double hPad = panelWidth * 0.055;

    return Material(
      color: _panelBg,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(12 * u)),
        side: const BorderSide(color: Color(0xFF3A3935)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: panelWidth,
        height: screen.height,
        child: SafeArea(
          left: false,
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          12 * u,
                          hPad,
                          // Keep fields above the on-screen keyboard.
                          6 * u + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        children: [
                          Text(
                            _isEdit ? 'Edit Patient' : 'Create New Patient',
                            style: TextStyle(
                              fontSize: 20 * u,
                              fontWeight: FontWeight.w700,
                              color: _gold,
                            ),
                          ),
                          SizedBox(height: 6 * u),
                          _photoBox(u, panelWidth),
                          SizedBox(height: 6 * u),
                          _label('Name', u),
                          _textField(
                            u,
                            controller: _name,
                            hint: 'Enter Patient Name',
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                          _gap(u),
                          _twoColumns(
                            u,
                            _column('DOB', u, [
                              _textField(
                                u,
                                controller: _dobText,
                                hint: '__-__-____',
                                icon: Icons.calendar_month_outlined,
                                readOnly: true,
                                onTap: _pickDob,
                              ),
                            ]),
                            _column('Consulting Doctor', u, [_doctorField(u)]),
                          ),
                          _gap(u),
                          _twoColumns(
                            u,
                            _column('Height', u, [
                              _textField(
                                u,
                                controller: _height,
                                hint: 'Enter Height',
                                icon: Icons.accessibility_new,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ]),
                            _column('Weight', u, [
                              _textField(
                                u,
                                controller: _weight,
                                hint: 'Enter Weight',
                                icon: Icons.monitor_weight_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ]),
                          ),
                          _gap(u),
                          _twoColumns(
                            u,
                            _column('Gender', u, [_genderField(u)]),
                            _column('Patient ID', u, [_patientIdField(u)]),
                          ),
                          _gap(u),
                          _label('Phone  Number', u),
                          _textField(
                            u,
                            controller: _phone,
                            hint: 'Enter Mobile Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              final String phone = v?.trim() ?? '';
                              if (phone.isNotEmpty && phone.length != 10) {
                                return 'Enter a 10-digit mobile number';
                              }
                              return null;
                            },
                          ),
                          _gap(u),
                          _label('Remark', u),
                          _textField(
                            u,
                            controller: _remark,
                            hint: '',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                    // Save stays pinned to the bottom of the panel.
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 6 * u, hPad, 10 * u),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: panelWidth * 0.46,
                          height: (32 * u).clamp(40.0, 60.0),
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8 * u),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    _isEdit ? 'Update' : 'Save',
                                    style: TextStyle(
                                      fontSize: _fs(u, 13),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(top: 12 * u, right: 12 * u, child: _closeButton(u)),
            ],
          ),
        ),
      ),
    );
  }

  static double _fs(double u, double base) {
    final double size = base * u;
    return size < 10 ? 10 : size;
  }

  Widget _gap(double u) => SizedBox(height: 7 * u);

  Widget _label(String text, double u) => Padding(
    padding: EdgeInsets.only(bottom: 5 * u),
    child: Text(
      text,
      style: TextStyle(
        fontSize: _fs(u, 11.5),
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    ),
  );

  Widget _column(String label, double u, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_label(label, u), ...children],
  );

  Widget _twoColumns(double u, Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      SizedBox(width: 8 * u),
      Expanded(child: b),
    ],
  );

  Widget _photoBox(double u, double panelWidth) {
    return Center(
      child: Material(
        color: const Color(0xFF242320),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * u),
          side: const BorderSide(color: Color(0xFF45433D)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8 * u),
          onTap: _capturePhoto,
          // Height follows the content so the label never gets clipped.
          child: Container(
            width: panelWidth * 0.55,
            padding: EdgeInsets.symmetric(vertical: 6 * u),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62 * u,
                  height: 62 * u,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E2D29),
                    border: Border.all(color: const Color(0xFF55524A)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _capturing
                      ? Padding(
                          padding: EdgeInsets.all(20 * u),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                          ),
                        )
                      : _photoPath != null
                      ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                      : Icon(
                          Icons.photo_camera_outlined,
                          size: 28 * u,
                          color: const Color(0xFF6E6C66),
                        ),
                ),
                SizedBox(height: 4 * u),
                Text(
                  _photoPath == null ? 'Capture Photo' : 'Tap to retake',
                  style: TextStyle(
                    fontSize: _fs(u, 10),
                    color: _photoPath == null
                        ? const Color(0xFF6E6C66)
                        : _goldMuted,
                  ),
                ),
                if (_photoError != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4 * u),
                    child: Text(
                      _photoError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _fs(u, 8.5),
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Height of a single-line field box (the text_box.png image).
  static double _fieldHeight(double u) => (44 * u).clamp(50.0, 70.0);

  /// Bottom strip of text_box.png that is only drop shadow; content is
  /// centred on the visible box above it.
  static const double _boxShadow = 8;

  InputDecoration _decoration(
    double u, {
    required String hint,
    IconData? icon,
    Widget? suffix,
    bool multiline = false,
  }) {
    final double circle = (26 * u).clamp(26.0, 40.0);
    return InputDecoration(
      isDense: true,
      filled: false,
      hintText: hint,
      hintStyle: TextStyle(fontSize: _fs(u, 11), color: _hint),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12 * u,
        vertical: multiline ? 10 * u : 0,
      ),
      prefixIcon: icon == null
          ? null
          : Padding(
              padding: EdgeInsets.only(left: 10 * u, right: 2 * u),
              child: Container(
                width: circle,
                height: circle,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C2A24),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: circle * 0.55, color: _goldMuted),
              ),
            ),
      prefixIconConstraints: BoxConstraints(minWidth: circle + 12 * u),
      suffixIcon: suffix,
      suffixIconConstraints: BoxConstraints(minWidth: 36 * u),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
  }

  /// Draws the text_box.png asset behind a field at a fixed [height]. The
  /// image is nine-sliced, so its rounded corners and gold bottom glow keep
  /// their shape at any size; a red outline marks a field with an error.
  Widget _assetBox(
    double u, {
    required Widget child,
    required double height,
    bool hasError = false,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/text_box.png'),
          centerSlice: Rect.fromLTRB(12, 10, 411, 44),
        ),
      ),
      padding: const EdgeInsets.only(bottom: _boxShadow),
      child: Container(
        alignment: alignment,
        foregroundDecoration: hasError
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8 * u),
                border: Border.all(color: Colors.redAccent),
              )
            : null,
        child: child,
      ),
    );
  }

  /// Error text shown under a field, outside the box image.
  Widget _errorText(double u, String text) => Padding(
    padding: EdgeInsets.only(top: 4 * u, left: 4 * u),
    child: Text(
      text,
      style: TextStyle(fontSize: _fs(u, 9.5), color: Colors.redAccent),
    ),
  );

  Widget _textField(
    double u, {
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    int maxLines = 1,
    Widget? suffix,
  }) {
    final bool multiline = maxLines > 1;
    return FormField<String>(
      // Reads the controller directly so programmatic changes (date picker,
      // dropdown menus) are validated too.
      validator: validator == null ? null : (_) => validator(controller.text),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _assetBox(
            u,
            height: _fieldHeight(u) * (multiline ? 1.4 : 1),
            hasError: field.hasError,
            alignment: multiline ? Alignment.topLeft : Alignment.centerLeft,
            child: TextField(
              controller: controller,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              readOnly: readOnly,
              onTap: onTap,
              maxLines: maxLines,
              minLines: 1,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textAlignVertical: TextAlignVertical.center,
              // Clear the error as soon as the user edits the field.
              onChanged: (v) {
                onChanged?.call(v);
                if (field.hasError) field.validate();
              },
              cursorColor: _gold,
              style: TextStyle(fontSize: _fs(u, 11), color: Colors.white),
              decoration: _decoration(
                u,
                hint: hint,
                icon: icon,
                suffix: suffix,
                multiline: multiline,
              ),
            ),
          ),
          if (field.hasError) _errorText(u, field.errorText!),
        ],
      ),
    );
  }

  /// Gold dropdown arrow that opens a menu of [options]; shows [emptyText]
  /// (disabled) when there is nothing to pick yet.
  Widget _arrowMenu(
    double u, {
    required List<String> options,
    required String emptyText,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.arrow_drop_down, color: _gold, size: 22 * u),
      color: _panelBg,
      onSelected: onSelected,
      itemBuilder: (_) => options.isEmpty
          ? [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  emptyText,
                  style: TextStyle(fontSize: _fs(u, 11), color: _hint),
                ),
              ),
            ]
          : [
              for (final o in options)
                PopupMenuItem<String>(
                  value: o,
                  child: Text(
                    o,
                    style: TextStyle(fontSize: _fs(u, 11), color: Colors.white),
                  ),
                ),
            ],
    );
  }

  /// Free text, plus a dropdown of doctors already used for other patients.
  Widget _doctorField(double u) {
    return _textField(
      u,
      controller: _doctor,
      hint: 'Enter Dr. Name',
      icon: Icons.person_pin_outlined,
      onChanged: (value) {
        final selected = _doctors.where(
          (doctor) => doctor.doctorId == _selectedDoctorId,
        );
        if (selected.isEmpty || selected.first.name != value) {
          _selectedDoctorId = null;
        }
      },
      suffix: _arrowMenu(
        u,
        options: _doctors.map((doctor) => doctor.name).toList(),
        emptyText: _loadingDoctors ? 'Loading doctors...' : 'No doctors found',
        onSelected: (name) {
          final doctor = _doctors.firstWhere((item) => item.name == name);
          setState(() {
            _selectedDoctorId = doctor.doctorId;
            _doctor.text = doctor.name;
          });
        },
      ),
    );
  }

  /// Free text; the arrow offers the next free auto-generated ID.
  Widget _patientIdField(double u) {
    return _textField(
      u,
      controller: _patientId,
      hint: 'Enter Patient ID',
      icon: Icons.badge_outlined,
      validator: (v) {
        final String id = v?.trim() ?? '';
        if (id.isNotEmpty &&
            PatientStore.instance.isIdTaken(id, except: widget.patient)) {
          return 'ID already in use';
        }
        return null;
      },
      suffix: _arrowMenu(
        u,
        options: [PatientStore.instance.nextPatientId()],
        emptyText: '',
        onSelected: (id) => setState(() => _patientId.text = id),
      ),
    );
  }

  Widget _genderField(double u) {
    return _assetBox(
      u,
      height: _fieldHeight(u),
      child: DropdownButtonFormField<String>(
        initialValue: _gender,
        isExpanded: true,
        dropdownColor: _panelBg,
        iconEnabledColor: _gold,
        icon: Padding(
          padding: EdgeInsets.only(right: 8 * u),
          child: Icon(Icons.arrow_drop_down, size: 22 * u),
        ),
        style: TextStyle(fontSize: _fs(u, 11), color: Colors.white),
        decoration: _decoration(u, hint: 'Choose Gender', icon: Icons.wc),
        hint: Text(
          'Choose Gender',
          style: TextStyle(fontSize: _fs(u, 11), color: _hint),
        ),
        items: [
          for (final g in _genders) DropdownMenuItem(value: g, child: Text(g)),
        ],
        onChanged: (g) => setState(() => _gender = g),
      ),
    );
  }

  Widget _closeButton(double u) {
    final double size = (26 * u).clamp(36.0, 52.0);
    return Material(
      color: const Color(0xFF3A3935),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.close, size: size * 0.45, color: Colors.white),
        ),
      ),
    );
  }
}
