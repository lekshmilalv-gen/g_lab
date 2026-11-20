import 'dart:io';

import 'package:flutter/material.dart';

import '../models/patient.dart';
import 'session_history_screen.dart';
import '../widgets/patient_form_panel.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  static const Color _gold = Color(0xFFE7CA55);
  static const Color _goldMuted = Color(0xFFA38B45);
  static const Color _cardBg = Color(0xFF2E2C28);
  static const Color _textMuted = Color(0xFF8A8A8A);

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    PatientStore.instance.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    final double screenWidth = screenSize.width;
    final double screenHeight = screenSize.height;

    // Same scale rule as the dashboard (920 x 575 reference design).
    final double s = [
      screenWidth / 920,
      screenHeight / 575,
    ].reduce((a, b) => a < b ? a : b).clamp(0.55, 2.2);

    final double gutter = screenWidth * 0.04;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dash_bg.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              screenHeight * 0.04,
              gutter,
              screenHeight * 0.03,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────────────────────────
                // LOGO
                // ─────────────────────────
                Image.asset(
                  'assets/images/app_logo.png',
                  height: screenHeight * 0.08,
                  fit: BoxFit.contain,
                ),

                SizedBox(height: screenHeight * 0.04),

                // ─────────────────────────
                // TITLE + SEARCH + CREATE
                // ─────────────────────────
                SizedBox(
                  height: screenWidth < 640
                      ? 100
                      : (screenHeight * 0.07).clamp(40.0, 64.0),
                  child: screenWidth < 640
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _backButton(s),
                                SizedBox(width: 10 * s),
                                Text(
                                  'Patient List',
                                  style: TextStyle(
                                    fontSize: 20 * s,
                                    fontWeight: FontWeight.w700,
                                    color: _gold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(child: _searchField(s)),
                                SizedBox(width: 8 * s),
                                _createButton(s),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            _backButton(s),
                            SizedBox(width: 10 * s),
                            Text(
                              'Patient List',
                              style: TextStyle(
                                fontSize: 20 * s,
                                fontWeight: FontWeight.w700,
                                color: _gold,
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: (screenWidth * 0.17).clamp(160.0, 320.0),
                              child: _searchField(s),
                            ),
                            SizedBox(width: 10 * s),
                            _createButton(s),
                          ],
                        ),
                ),

                SizedBox(height: screenHeight * 0.03),

                // ─────────────────────────
                // PATIENTS / EMPTY STATE
                // ─────────────────────────
                Expanded(
                  child: ListenableBuilder(
                    listenable: PatientStore.instance,
                    builder: (context, _) => _buildBody(s, screenWidth),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _fs(double s, double base) {
    final double size = base * s;
    return size < 10 ? 10 : size;
  }

  List<Patient> _filtered(List<Patient> all) {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.patientId.toLowerCase().contains(q),
        )
        .toList();
  }

  Widget _buildBody(double s, double screenWidth) {
    final PatientStore store = PatientStore.instance;
    final List<Patient> all = store.patients;
    final List<Patient> shown = _filtered(all);

    if (all.isEmpty && store.loading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (all.isEmpty && store.error != null) {
      return _emptyState(
        s,
        icon: Icons.cloud_off_outlined,
        title: 'Could not load patients',
        message: store.error!,
        action: _retryButton(s),
      );
    }
    if (all.isEmpty) {
      return _emptyState(
        s,
        icon: Icons.group_add_outlined,
        title: 'No patients found',
        message:
            'No patients have been added yet.\n'
            'Tap "Create New Patient" at the top right to add one.',
      );
    }
    if (shown.isEmpty) {
      return _emptyState(
        s,
        icon: Icons.search_off_outlined,
        title: 'No matching patients',
        message: 'No patient name or ID matches "${_query.trim()}".',
      );
    }

    final int columns = screenWidth >= 1000
        ? 5
        : screenWidth >= 760
        ? 4
        : 3;
    return RefreshIndicator(
      color: _gold,
      onRefresh: store.load,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: 12 * s),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10 * s,
          mainAxisSpacing: 10 * s,
          childAspectRatio: 1.3,
        ),
        itemCount: shown.length,
        itemBuilder: (context, i) => _patientCard(s, shown[i]),
      ),
    );
  }

  Widget _retryButton(double s) {
    return OutlinedButton.icon(
      onPressed: PatientStore.instance.load,
      style: OutlinedButton.styleFrom(
        foregroundColor: _gold,
        side: const BorderSide(color: _gold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8 * s),
        ),
      ),
      icon: Icon(Icons.refresh, size: 14 * s),
      label: Text('Retry', style: TextStyle(fontSize: _fs(s, 9))),
    );
  }

  // ───────────────────────────────────────────
  // Header widgets
  // ───────────────────────────────────────────

  Widget _backButton(double s) {
    final double size = (18 * s).clamp(36.0, 48.0);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _gold, width: 1.6),
        ),
        child: Icon(Icons.arrow_back, size: size * 0.55, color: _gold),
      ),
    );
  }

  Widget _searchField(double s) {
    return SizedBox(
      height: (28 * s).clamp(48.0, 60.0),
      child: TextField(
        controller: _search,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onChanged: (v) => setState(() => _query = v),
        cursorColor: _gold,
        style: TextStyle(fontSize: _fs(s, 8.5), color: Colors.white),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF1A1916),
          hintText: 'Search',
          hintStyle: TextStyle(fontSize: _fs(s, 8.5), color: _textMuted),
          prefixIcon: Icon(Icons.search, size: 14 * s, color: _textMuted),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: 13 * s, color: _textMuted),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                  }),
                ),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8 * s),
            borderSide: BorderSide(color: _goldMuted.withValues(alpha: 0.6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8 * s),
            borderSide: BorderSide(color: _gold, width: 2 * s),
          ),
        ),
      ),
    );
  }

  Widget _createButton(double s) {
    return SizedBox(
      height: (28 * s).clamp(48.0, 60.0),
      child: ElevatedButton.icon(
        onPressed: () => showPatientFormPanel(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8 * s),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20 * s),
        ),
        icon: Icon(Icons.add, size: 18 * s),
        label: Text(
          'Create New Patient',
          style: TextStyle(fontSize: _fs(s, 11), fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  // Body widgets
  // ───────────────────────────────────────────

  Widget _emptyState(
    double s, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76 * s,
              height: 76 * s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF221F17),
                border: Border.all(color: _gold.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.12),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Icon(icon, size: 34 * s, color: _gold),
            ),
            SizedBox(height: 14 * s),
            Text(
              title,
              style: TextStyle(
                fontSize: _fs(s, 14),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _fs(s, 9),
                color: _textMuted,
                height: 1.5,
              ),
            ),
            if (action != null) ...[SizedBox(height: 14 * s), action],
          ],
        ),
      ),
    );
  }

  Widget _patientCard(double s, Patient patient) {
    return Material(
      color: _cardBg,
      elevation: 6,
      shadowColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * s),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionHistoryScreen(patient: patient),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(8 * s),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _avatar(s, patient.photoPath),
                    SizedBox(height: 8 * s),
                    Text(
                      patient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _fs(s, 9.5),
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2 * s),
                    Text(
                      'Patient ID : ${patient.patientId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: _fs(s, 7), color: _textMuted),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 6 * s,
              right: 6 * s,
              child: Tooltip(
                message: 'Edit patient',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showPatientFormPanel(context, patient: patient),
                  child: Container(
                    width: (16 * s).clamp(28.0, 40.0),
                    height: (16 * s).clamp(28.0, 40.0),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1A1916),
                    ),
                    child: Icon(Icons.edit_note, size: 11 * s, color: _gold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(double s, String? photoPath) {
    return Container(
      width: 42 * s,
      height: 42 * s,
      padding: EdgeInsets.all(2.5 * s),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_gold, Color(0xFF5A4A1E)],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF3A3833),
        ),
        clipBehavior: Clip.antiAlias,
        child: photoPath != null
            ? Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                // Falls back to the default icon if the file is gone.
                errorBuilder: (_, _, _) => _defaultAvatarIcon(s),
              )
            : _defaultAvatarIcon(s),
      ),
    );
  }

  Widget _defaultAvatarIcon(double s) =>
      Icon(Icons.person, size: 24 * s, color: const Color(0xFFBDBDBD));
}
