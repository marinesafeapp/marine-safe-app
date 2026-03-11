import 'package:flutter/material.dart';

class SponsorManagerScreen extends StatelessWidget {
  const SponsorManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Manage Sponsors"),
      ),
      body: const Center(
        child: Text("Sponsor Manager Coming Soon",
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
