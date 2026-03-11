import 'package:flutter/material.dart';

import '../models/ramp_location.dart';
import '../services/ramp_storage_service.dart';
import 'ramp_details_screen.dart';

class OtherRampsScreen extends StatefulWidget {
  const OtherRampsScreen({super.key});

  @override
  State<OtherRampsScreen> createState() => _OtherRampsScreenState();
}

class _OtherRampsScreenState extends State<OtherRampsScreen> {
  List<RampLocation> ramps = [];

  @override
  void initState() {
    super.initState();
    _loadRamps();
  }

  Future<void> _loadRamps() async {
    final list = await RampStorageService.loadAllRamps();
    if (mounted) setState(() => ramps = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ramps.length,
        itemBuilder: (context, index) {
          final ramp = ramps[index];

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(ramp.name),
              subtitle: Text(ramp.address),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RampDetailsScreen(ramp: ramp),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
