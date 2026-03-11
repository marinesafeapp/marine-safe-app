import 'package:flutter/material.dart';

class AdminSponsorListScreen extends StatelessWidget {
  const AdminSponsorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Manage Sponsors"),
      ),
      body: const Center(
        child: Text(
          "Sponsor management coming soon...",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}