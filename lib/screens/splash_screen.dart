import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_profile_service.dart';
import '../main_shell.dart';
import 'name_setup_screen.dart';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _profile = UserProfileService.instance;
  static const String _kRegistered = 'app.registered';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Show logo for at least 1.5s so it's visible before main page
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Force a full “new user” setup on first install
    final p = await SharedPreferences.getInstance();
    final registered = p.getBool(_kRegistered) ?? false;
    if (!registered) {
      // Clear any leftover profile data so new users see empty fields everywhere
      final keys = p.getKeys().where((k) => k.startsWith('profile.')).toList();
      for (final k in keys) {
        await p.remove(k);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
      return;
    }

    final name = await _profile.getUserName();

    if (!mounted) return;

    if (name == null || name.trim().isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NameSetupScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  // Try marine_safe_logo_full.png first; actual file may be marine_safe_logo_full.png.jpg
  static const List<String> _logoPaths = [
    'assets/branding/marine_safe_logo_full.png',
    'assets/branding/marine_safe_logo_full.png.jpg',
    'assets/branding/marine_safe_app_icons/marine_safe_logo_full1.png',
  ];

  Widget _buildLogo() {
    return Image.asset(
      _logoPaths.first,
      fit: BoxFit.contain,
      width: 280,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _buildLogoFallback(1),
    );
  }

  Widget _buildLogoFallback(int index) {
    if (index >= _logoPaths.length) {
      return const Icon(Icons.directions_boat, size: 80, color: Colors.white54);
    }
    return Image.asset(
      _logoPaths[index],
      fit: BoxFit.contain,
      width: 280,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _buildLogoFallback(index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
