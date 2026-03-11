import 'package:flutter/material.dart';

import '../models/ramp_location.dart';
import '../services/ramp_storage_service.dart';
import 'edit_ramp_screen.dart';

class RampManagerScreen extends StatefulWidget {
  const RampManagerScreen({super.key});

  @override
  State<RampManagerScreen> createState() => _RampManagerScreenState();
}

class _RampManagerScreenState extends State<RampManagerScreen> {
  List<RampLocation> adminRamps = [];

  @override
  void initState() {
    super.initState();
    loadRamps();
  }

  Future<void> loadRamps() async {
    adminRamps = await RampStorageService.loadRamps();
    if (mounted) setState(() {});
  }

  Future<void> deleteRamp(int index) async {
    final ramp = adminRamps[index];
    await RampStorageService.deleteRamp(ramp);
    if (mounted) await loadRamps();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Manage Ramps"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditRampScreen(),
                ),
              );
              loadRamps();
            },
          ),
        ],
      ),

      body: ListView.builder(
        itemCount: adminRamps.length,
        itemBuilder: (context, index) {
          final ramp = adminRamps[index];
          return ListTile(
            tileColor: const Color(0xFF11161C),
            title: Text(ramp.name,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(ramp.address,
                style: const TextStyle(color: Colors.white70)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditRampScreen(existingRamp: ramp),
                      ),
                    );
                    loadRamps();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => deleteRamp(index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
