import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  static const _kAdminPin = 'admin.pin';
  static const _kAdminUntil = 'admin.untilMs';

  final _pinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();

  bool _showPin = false;
  bool _loading = true;

  String _currentPin = "1234";
  DateTime? _unlockedUntil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _newPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    _currentPin = p.getString(_kAdminPin) ?? "1234";
    final untilMs = p.getInt(_kAdminUntil);
    _unlockedUntil =
    untilMs == null ? null : DateTime.fromMillisecondsSinceEpoch(untilMs);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  bool get _isUnlocked =>
      _unlockedUntil != null && DateTime.now().isBefore(_unlockedUntil!);

  Future<void> _unlock() async {
    final entered = _pinCtrl.text.trim();
    if (entered != _currentPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong PIN ❌")),
      );
      return;
    }

    final p = await SharedPreferences.getInstance();
    final until = DateTime.now().add(const Duration(minutes: 30));
    await p.setInt(_kAdminUntil, until.millisecondsSinceEpoch);

    if (!mounted) return;
    setState(() => _unlockedUntil = until);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Admin unlocked ✅ (30 minutes)")),
    );
    Navigator.pop(context, true); // tell drawer we unlocked
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kAdminUntil);

    if (!mounted) return;
    setState(() => _unlockedUntil = null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Admin locked 🔒")),
    );
  }

  Future<void> _changePin() async {
    final newPin = _newPinCtrl.text.trim();
    if (newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PIN must be at least 4 digits.")),
      );
      return;
    }
    if (int.tryParse(newPin) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PIN must be numbers only.")),
      );
      return;
    }

    final p = await SharedPreferences.getInstance();
    await p.setString(_kAdminPin, newPin);
    _currentPin = newPin;
    _newPinCtrl.clear();

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Admin PIN updated ✅")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        elevation: 0,
        title: const Text("Admin Access",
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
              color: Colors.white.withValues(alpha:0.06),
            ),
            child: Row(
              children: [
                Icon(
                  _isUnlocked ? Icons.lock_open : Icons.lock,
                  color: _isUnlocked ? Colors.greenAccent : Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isUnlocked
                        ? "Admin UNLOCKED until ${_unlockedUntil!.hour.toString().padLeft(2, '0')}:${_unlockedUntil!.minute.toString().padLeft(2, '0')}"
                        : "Admin LOCKED",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_isUnlocked)
                  TextButton(
                    onPressed: _logout,
                    child: const Text("Logout"),
                  )
              ],
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
              color: Colors.white.withValues(alpha:0.06),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter Admin PIN",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: !_showPin,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "PIN",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha:0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _showPin = !_showPin),
                      icon: Icon(
                        _showPin ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _unlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withValues(alpha:0.25),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Unlock Admin"),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Default PIN is 1234 (change it below).",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
              color: Colors.white.withValues(alpha:0.06),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Change Admin PIN",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newPinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "New PIN (numbers only)",
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha:0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _changePin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha:0.25)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text("Save New PIN"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
