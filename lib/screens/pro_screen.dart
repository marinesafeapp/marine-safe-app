import 'package:flutter/material.dart';

import '../services/user_profile_service.dart';

/// Pro / paid tier: multiple vessels, invite crew. Upgrade entry point.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);

  bool _isPro = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isPro = await UserProfileService.instance.getIsPro();
    if (mounted) {
      setState(() {
        _isPro = isPro;
        _loaded = true;
      });
    }
  }

  Future<void> _togglePro(bool value) async {
    await UserProfileService.instance.setPro(value);
    if (mounted) setState(() => _isPro = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          "Marine Safe Pro",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPro ? "You have Pro" : "Upgrade to Pro",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "• Multiple vessels — add and switch between boats\n"
                        "• Invite crew — when people on board > 1, share a code so others can log on to the same boat and see the trip",
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (_isPro)
                        OutlinedButton(
                          onPressed: () => _togglePro(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white38),
                          ),
                          child: const Text("Disable Pro"),
                        )
                      else
                        FilledButton(
                          onPressed: () => _togglePro(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Enable Pro"),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Pro unlocks multiple vessels and crew invite. Enable above to use these features.",
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
              ],
            ),
    );
  }
}
