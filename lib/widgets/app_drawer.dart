import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/moderator/moderator_screen.dart';

import '../screens/admin_login_screen.dart';
import '../screens/register_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const _kAdminUntil = 'admin.untilMs';

  Future<bool> _isRegistered() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('app.registered') ?? false;
  }

  Future<bool> _isAdminUnlocked() async {
    final p = await SharedPreferences.getInstance();
    final untilMs = p.getInt(_kAdminUntil);
    if (untilMs == null) return false;
    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    return DateTime.now().isBefore(until);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF02050A),
        child: FutureBuilder<List<bool>>(
          future: Future.wait([_isRegistered(), _isAdminUnlocked()]),
          builder: (context, snap) {
            final registered = snap.data?[0] == true;
            final adminUnlocked = snap.data?[1] == true;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(color: Color(0xFF02050A)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "Marine Safe",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        registered ? "Registered ✅" : "Not registered 🔒",
                        style: TextStyle(
                          color: registered ? Colors.greenAccent : Colors.white54,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        adminUnlocked ? "Admin: UNLOCKED ✅" : "Admin: LOCKED 🔒",
                        style: TextStyle(
                          color: adminUnlocked ? Colors.greenAccent : Colors.white54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!registered) ...[
                  _item(
                    context,
                    icon: Icons.app_registration_rounded,
                    label: "Register",
                    go: () => _pushReplaceAll(context, const RegisterScreen()),
                  ),
                ] else ...[
                  _item(
                    context,
                    icon: Icons.home_rounded,
                    label: "Home",
                    go: () => _push(context, const HomeScreen()),
                  ),
                  _item(
                    context,
                    icon: Icons.person_rounded,
                    label: "My Profile",
                    go: () => _push(context, const ProfileScreen()),
                  ),
                  const Divider(color: Colors.white12),

                  _item(
                    context,
                    icon: Icons.lock_rounded,
                    label: "Admin Login",
                    go: () async {
                      Navigator.pop(context);
                      final unlockedNow = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                      );

                      if (unlockedNow == true && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModeratorScreen()),
                        );
                      }
                    },
                  ),

                  if (adminUnlocked)
                    _item(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      label: "Moderator",
                      go: () => _push(context, const ModeratorScreen()),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _item(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback go,
      }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      onTap: go,
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  static void _pushReplaceAll(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
          (_) => false,
    );
  }
}
