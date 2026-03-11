import 'package:flutter/material.dart';

class RampsScreen extends StatelessWidget {
  const RampsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Australian Ramps'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Boat ramps nationwide — list + details coming next.',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
