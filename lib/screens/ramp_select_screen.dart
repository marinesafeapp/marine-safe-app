import 'package:flutter/material.dart';

import '../models/ramp_location.dart';
import '../services/ramp_storage_service.dart';
import 'ramp_details_screen.dart';

class RampSelectScreen extends StatefulWidget {
  const RampSelectScreen({super.key});

  @override
  State<RampSelectScreen> createState() => _RampSelectScreenState();
}

class _RampSelectScreenState extends State<RampSelectScreen> {
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
      backgroundColor: const Color(0xFFEFF7FF),
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          "Select Boat Ramp",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ramps.length,
        itemBuilder: (context, index) {
          final ramp = ramps[index];

          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ramp.imageUrl != null
                    ? Image.network(
                        ramp.imageUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[300],
                        child: const Icon(Icons.photo, color: Colors.white),
                      ),
              ),
              title: Text(
                ramp.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                ramp.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.blue),
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
