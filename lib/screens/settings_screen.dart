import 'package:flutter/material.dart';

import 'reliability/reliability_check_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF02050A),
        title: const Text("System Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: Colors.white70),
            title: const Text(
              "Alert Reliability",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              "Ensure overdue alerts work when app is closed",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReliabilityCheckScreen(showContinueButton: false),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
