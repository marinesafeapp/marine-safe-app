import 'package:flutter/material.dart';

import '../models/ramp_location.dart';

class RampDetailsScreen extends StatelessWidget {
  final RampLocation ramp;

  const RampDetailsScreen({super.key, required this.ramp});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ramp.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ramp.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  ramp.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              ramp.address,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 8),
                Text("Lat: ${ramp.lat.toStringAsFixed(5)}"),
                const SizedBox(width: 16),
                Text("Lon: ${ramp.lon.toStringAsFixed(5)}"),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip("Lanes: ${ramp.lanes}"),
                _chip("Parking: ${ramp.parking ? "Yes" : "No"}"),
                _chip("Toilets: ${ramp.toilets ? "Yes" : "No"}"),
                _chip("Pontoon: ${ramp.pontoon ? "Yes" : "No"}"),
                _chip("Lighting: ${ramp.lighting ? "Yes" : "No"}"),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Hazards",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...ramp.hazards.map(
              (h) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("• "),
                  Expanded(child: Text(h)),
                ],
              ),
            ),
            if (ramp.adminNotes != null && ramp.adminNotes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                "Admin Notes",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(ramp.adminNotes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.blue.shade50,
      side: BorderSide(color: Colors.blue.shade100),
    );
  }
}
