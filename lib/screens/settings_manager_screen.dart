import 'package:flutter/material.dart';

class SettingsManagerScreen extends StatelessWidget {
  const SettingsManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("System Settings"),
      ),
      body: const Center(
        child: Text("Settings Coming Soon",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
