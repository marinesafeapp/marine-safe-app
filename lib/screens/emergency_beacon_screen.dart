import 'dart:async';
import 'package:flutter/material.dart';

class EmergencyBeaconScreen extends StatefulWidget {
  const EmergencyBeaconScreen({super.key});

  @override
  State<EmergencyBeaconScreen> createState() => _EmergencyBeaconScreenState();
}

class _EmergencyBeaconScreenState extends State<EmergencyBeaconScreen> {
  bool _red = true;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _startFlashing();
  }

  void _startFlashing() {
    _flashTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      setState(() {
        _red = !_red;
      });
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _red ? Colors.red.shade800 : Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 120, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "EMERGENCY BEACON ACTIVE",
              style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 20),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "STOP BEACON",
                style: TextStyle(fontSize: 20),
              ),
            )
          ],
        ),
      ),
    );
  }
}
