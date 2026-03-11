import 'package:flutter/material.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Safety Gear'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Safety Gear section (expiry dates, checklist) — coming next.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
