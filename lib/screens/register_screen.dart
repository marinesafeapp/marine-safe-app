import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main_shell.dart';
import '../services/profile_cloud_service.dart';
import '../services/user_profile_service.dart';
import 'home/services/trip_prefs.dart';
import 'reliability/reliability_check_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _kRegistered = 'app.registered';

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();

  // ✅ Emergency Contact 1 (mandatory)
  final _emg1NameCtrl = TextEditingController();
  final _emg1PhoneCtrl = TextEditingController();
  final _emg1RelCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _postcodeCtrl.dispose();
    _emg1NameCtrl.dispose();
    _emg1PhoneCtrl.dispose();
    _emg1RelCtrl.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) {
    final e = s.trim();
    return e.contains("@") && e.contains(".");
  }

  bool _looksLikePostcode(String s) {
    final t = s.trim();
    if (t.length != 4) return false;
    return int.tryParse(t) != null;
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final postcode = _postcodeCtrl.text.trim();

    final emg1Name = _emg1NameCtrl.text.trim();
    final emg1Phone = _emg1PhoneCtrl.text.trim();
    final emg1Rel = _emg1RelCtrl.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        postcode.isEmpty ||
        emg1Name.isEmpty ||
        emg1Phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill Name, Phone, Email, Postcode + Emergency Contact 1."),
        ),
      );
      return;
    }

    if (!_looksLikePostcode(postcode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a 4-digit Australian postcode.")),
      );
      return;
    }

    if (!_looksLikeEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address.")),
      );
      return;
    }

    setState(() => _saving = true);

    final p = await SharedPreferences.getInstance();

    // ✅ Save profile basics (same keys as Profile screen)
    await p.setString('profile.name', name);
    await p.setString('profile.phone', phone);
    await p.setString('profile.email', email);
    await UserProfileService.instance.setPostcode(postcode);

    // ✅ Save Emergency Contact 1 (same keys as emergency feature)
    await p.setString('profile.emg1.name', emg1Name);
    await p.setString('profile.emg1.phone', emg1Phone);
    await p.setString('profile.emg1.relation', emg1Rel);

    // ✅ Mark registered
    await p.setBool(_kRegistered, true);

    // Keep the app-wide user name consistent
    await UserProfileService.instance.setUserName(name);

    // Best-effort cloud sync (don’t block registration if offline)
    try {
      await ProfileCloudService.saveMyProfile(
        displayName: name,
        email: email,
        phone: phone,
        emergencyName: emg1Name,
        emergencyPhone: emg1Phone,
      );
    } catch (_) {}

    if (!mounted) return;
    setState(() => _saving = false);

    // Show Alert Reliability once (then never again per trip)
    final alreadyAcknowledged = await TripPrefs.getAlertReliabilityAcknowledged();
    if (!alreadyAcknowledged) {
      final continued = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const ReliabilityCheckScreen(showContinueButton: true),
        ),
      );
      if (!mounted) return;
      if (continued == true) await TripPrefs.setAlertReliabilityAcknowledged(true);
    }

    if (!mounted) return;
    // Open directly to Profile (tab index 3) after first-time registration
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 3)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        elevation: 0,
        title: const Text(
          "Register",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cardText(
            "Required: Name, Phone, Email, Postcode (4 digits), and Emergency Contact 1. "
                "Postcode is used to show ramps near you.",
          ),
          const SizedBox(height: 14),

          _sectionTitle("Personal"),
          _field(_nameCtrl, "Name"),
          _field(_phoneCtrl, "Phone", keyboard: TextInputType.phone),
          _field(_emailCtrl, "Email", keyboard: TextInputType.emailAddress),
          _postcodeField(),

          const SizedBox(height: 14),

          _sectionTitle("Emergency Contact 1 (Required)"),
          _field(_emg1NameCtrl, "Contact name"),
          _field(_emg1PhoneCtrl, "Contact phone", keyboard: TextInputType.phone),
          _field(_emg1RelCtrl, "Relationship (optional)"),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent.withValues(alpha:0.25),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? "Saving..." : "Create Profile"),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "You can add Emergency Contact 2 and safety equipment later in My Profile.",
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _cardText(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        color: Colors.white.withValues(alpha:0.06),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.4)),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController c,
      String hint, {
        TextInputType keyboard = TextInputType.text,
      }) {
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
          fillColor: Colors.white.withValues(alpha:0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
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
        decoration: const InputDecoration(
          hintText: "Postcode (e.g. 4740)",
          hintStyle: TextStyle(color: Colors.white38),
          counterText: "",
          filled: true,
          fillColor: Colors.white12,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
