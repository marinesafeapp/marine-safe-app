import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Firebase cloud profile sync
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/user_profile_service.dart';
import 'admin_login_screen.dart';
import 'moderator/moderator_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ---------- Storage Keys ----------
  static const _kName = 'profile.name';
  static const _kPhone = 'profile.phone';
  static const _kEmail = 'profile.email';
  static const _kPostcode = 'profile.postcode';

  static const _kEmg1Name = 'profile.emg1.name';
  static const _kEmg1Phone = 'profile.emg1.phone';
  static const _kEmg1Relation = 'profile.emg1.relation';

  static const _kEmg2Name = 'profile.emg2.name';
  static const _kEmg2Phone = 'profile.emg2.phone';
  static const _kEmg2Relation = 'profile.emg2.relation';

  // ---------- Controllers ----------
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();

  final _emg1NameCtrl = TextEditingController();
  final _emg1PhoneCtrl = TextEditingController();
  final _emg1RelationCtrl = TextEditingController();

  final _emg2NameCtrl = TextEditingController();
  final _emg2PhoneCtrl = TextEditingController();
  final _emg2RelationCtrl = TextEditingController();

  // ---------- UI state ----------
  bool _loaded = false;
  bool _dirty = false;
  bool _userExpanded = false;
  bool _emg1Expanded = false;
  bool _emg2Expanded = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _postcodeCtrl.dispose();

    _emg1NameCtrl.dispose();
    _emg1PhoneCtrl.dispose();
    _emg1RelationCtrl.dispose();

    _emg2NameCtrl.dispose();
    _emg2PhoneCtrl.dispose();
    _emg2RelationCtrl.dispose();
    super.dispose();
  }

  // ---------- Persistence ----------

  // ---------- Firebase (Cloud Profile) ----------
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final u = _auth.currentUser;
    if (u == null) return null;
    return _db.collection('users').doc(u.uid);
  }

  void _setCtrlIfNotEmpty(TextEditingController c, dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isNotEmpty) c.text = s;
  }

  Future<void> _loadFromCloud() async {
    final ref = _userRef;
    if (ref == null) return;

    try {
      final snap = await ref.get();
      if (!snap.exists) return;

      final d = snap.data() ?? <String, dynamic>{};

      // Personal
      _setCtrlIfNotEmpty(_nameCtrl, d['displayName'] ?? d['name']);
      _setCtrlIfNotEmpty(_phoneCtrl, d['phone']);
      _setCtrlIfNotEmpty(_emailCtrl, d['email']);
      _setCtrlIfNotEmpty(_postcodeCtrl, d['postcode']);

      // Emergency (support both nested + flat)
      if (d['emergency1'] is Map) {
        final emg1 = Map<String, dynamic>.from(d['emergency1']);
        _setCtrlIfNotEmpty(_emg1NameCtrl, emg1['name']);
        _setCtrlIfNotEmpty(_emg1PhoneCtrl, emg1['phone']);
        _setCtrlIfNotEmpty(_emg1RelationCtrl, emg1['relation']);
      } else {
        _setCtrlIfNotEmpty(_emg1NameCtrl, d['emergencyName']);
        _setCtrlIfNotEmpty(_emg1PhoneCtrl, d['emergencyPhone']);
      }

      if (d['emergency2'] is Map) {
        final emg2 = Map<String, dynamic>.from(d['emergency2']);
        _setCtrlIfNotEmpty(_emg2NameCtrl, emg2['name']);
        _setCtrlIfNotEmpty(_emg2PhoneCtrl, emg2['phone']);
        _setCtrlIfNotEmpty(_emg2RelationCtrl, emg2['relation']);
      }
    } catch (_) {
      // ignore (offline / permissions)
    }
  }

  Future<void> _saveToCloud() async {
    final ref = _userRef;
    if (ref == null) return;

    final now = DateTime.now();

    final data = <String, dynamic>{
      // Personal
      'displayName': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'postcode': _postcodeCtrl.text.trim(),

      // Emergency (nested + flat for fast rescue screens)
      'emergency1': {
        'name': _emg1NameCtrl.text.trim(),
        'phone': _emg1PhoneCtrl.text.trim(),
        'relation': _emg1RelationCtrl.text.trim(),
      },
      'emergency2': {
        'name': _emg2NameCtrl.text.trim(),
        'phone': _emg2PhoneCtrl.text.trim(),
        'relation': _emg2RelationCtrl.text.trim(),
      },
      'emergencyName': _emg1NameCtrl.text.trim(),
      'emergencyPhone': _emg1PhoneCtrl.text.trim(),

      // Metadata
      'updatedAt': now.toIso8601String(),
      'updatedAtMs': now.millisecondsSinceEpoch,
    };

    // Remove empty strings so Firestore stays clean
    data.removeWhere((k, v) => v is String && v.trim().isEmpty);

    await ref.set(data, SetOptions(merge: true));
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();

    _nameCtrl.text = p.getString(_kName) ?? '';
    _phoneCtrl.text = p.getString(_kPhone) ?? '';
    _emailCtrl.text = p.getString(_kEmail) ?? '';
    _postcodeCtrl.text = p.getString(_kPostcode) ?? '';

    _emg1NameCtrl.text = p.getString(_kEmg1Name) ?? '';
    _emg1PhoneCtrl.text = p.getString(_kEmg1Phone) ?? '';
    _emg1RelationCtrl.text = p.getString(_kEmg1Relation) ?? '';

    _emg2NameCtrl.text = p.getString(_kEmg2Name) ?? '';
    _emg2PhoneCtrl.text = p.getString(_kEmg2Phone) ?? '';
    _emg2RelationCtrl.text = p.getString(_kEmg2Relation) ?? '';

    await _loadFromCloud();

    if (!mounted) return;
    setState(() {
      _loaded = true;
      _dirty = false;
    });
  }

  Future<void> _clearLocal() async {
    final p = await SharedPreferences.getInstance();

    // Clear controllers
    _nameCtrl.text = '';
    _phoneCtrl.text = '';
    _emailCtrl.text = '';
    _postcodeCtrl.text = '';
    _emg1NameCtrl.text = '';
    _emg1PhoneCtrl.text = '';
    _emg1RelationCtrl.text = '';
    _emg2NameCtrl.text = '';
    _emg2PhoneCtrl.text = '';
    _emg2RelationCtrl.text = '';

    // Clear local saved values (cloud is left as-is unless user saves)
    await p.remove(_kName);
    await p.remove(_kPhone);
    await p.remove(_kEmail);
    await p.remove(_kPostcode);
    await p.remove(_kEmg1Name);
    await p.remove(_kEmg1Phone);
    await p.remove(_kEmg1Relation);
    await p.remove(_kEmg2Name);
    await p.remove(_kEmg2Phone);
    await p.remove(_kEmg2Relation);

    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile cleared (local)')),
    );
  }

  Future<void> _save() async {
    // Update postcode first and clear geocode cache so Trip tab shows ramps near new postcode
    final postcode = _postcodeCtrl.text.trim();
    await UserProfileService.instance.setPostcode(postcode.isEmpty ? '' : postcode);

    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, _nameCtrl.text.trim());
    await p.setString(_kPhone, _phoneCtrl.text.trim());
    await p.setString(_kEmail, _emailCtrl.text.trim());
    await p.setString(_kPostcode, postcode);

    await p.setString(_kEmg1Name, _emg1NameCtrl.text.trim());
    await p.setString(_kEmg1Phone, _emg1PhoneCtrl.text.trim());
    await p.setString(_kEmg1Relation, _emg1RelationCtrl.text.trim());

    await p.setString(_kEmg2Name, _emg2NameCtrl.text.trim());
    await p.setString(_kEmg2Phone, _emg2PhoneCtrl.text.trim());
    await p.setString(_kEmg2Relation, _emg2RelationCtrl.text.trim());

    try {
      await _saveToCloud();
    } catch (_) {
      // ignore (offline / permissions)
    }

    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Saved ✅ (Device + Cloud)")),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        elevation: 0,
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: "Save",
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 20 + bottomPad),
        children: [
          _sectionCard(
            title: "User",
            expanded: _userExpanded,
            onToggle: () => setState(() => _userExpanded = !_userExpanded),
            children: [
              _textField(_nameCtrl, "Full name"),
              _textField(_phoneCtrl, "Phone"),
              _textField(_emailCtrl, "Email"),
              _postcodeField(),
            ],
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: "Emergency Contact 1 (Primary)",
            expanded: _emg1Expanded,
            onToggle: () => setState(() => _emg1Expanded = !_emg1Expanded),
            children: [
              _textField(_emg1NameCtrl, "Name"),
              _textField(_emg1PhoneCtrl, "Phone"),
              _textField(_emg1RelationCtrl, "Relation (e.g. Partner/Dad)"),
            ],
          ),
          const SizedBox(height: 12),

          _sectionCard(
            title: "Emergency Contact 2 (Optional)",
            expanded: _emg2Expanded,
            onToggle: () => setState(() => _emg2Expanded = !_emg2Expanded),
            children: [
              _textField(_emg2NameCtrl, "Name"),
              _textField(_emg2PhoneCtrl, "Phone"),
              _textField(_emg2RelationCtrl, "Relation"),
            ],
          ),

          if (kDebugMode) ...[
            const SizedBox(height: 18),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: _isAdminUnlocked(),
              builder: (context, snap) {
                final adminUnlocked = snap.data == true;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_rounded, color: Colors.white70),
                      title: const Text(
                        "Admin Login",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () async {
                        final unlockedNow = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminLoginScreen(),
                          ),
                        );
                        if (unlockedNow == true && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ModeratorScreen(),
                            ),
                          );
                        }
                      },
                    ),
                    if (adminUnlocked)
                      ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          "Moderator",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ModeratorScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          if (_dirty)
            const Text(
              "Unsaved changes",
              style: TextStyle(color: Colors.orangeAccent),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  static const String _kAdminUntil = 'admin.untilMs';

  Future<bool> _isAdminUnlocked() async {
    final p = await SharedPreferences.getInstance();
    final untilMs = p.getInt(_kAdminUntil);
    if (untilMs == null) return false;
    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    return DateTime.now().isBefore(until);
  }

  // ---------- UI helpers ----------
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    bool expanded = true,
    VoidCallback? onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onToggle ?? () {},
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (onToggle != null)
                          Icon(
                            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: Colors.white70,
                            size: 28,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController c, String hint,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.black.withValues(alpha:0.25),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onChanged: (_) => setState(() => _dirty = true),
      ),
    );
  }

  Widget _postcodeField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _postcodeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 4,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Postcode (e.g. 4740)",
          hintStyle: const TextStyle(color: Colors.white38),
          counterText: "",
          filled: true,
          fillColor: Colors.black.withValues(alpha:0.25),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onChanged: (_) => setState(() => _dirty = true),
      ),
    );
  }
}
