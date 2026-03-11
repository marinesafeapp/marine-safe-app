import 'package:flutter/material.dart';

import '../models/ramp_location.dart';
import '../services/ramp_storage_service.dart';

class AdminEditRampScreen extends StatefulWidget {
  final bool isNew;
  final RampLocation? ramp;

  const AdminEditRampScreen({
    super.key,
    this.isNew = false,
    this.ramp,
  });

  @override
  State<AdminEditRampScreen> createState() => _AdminEditRampScreenState();
}

class _AdminEditRampScreenState extends State<AdminEditRampScreen> {
  late TextEditingController nameController;
  late TextEditingController addressController;
  late TextEditingController latController;
  late TextEditingController lonController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.ramp?.name ?? "");
    addressController = TextEditingController(text: widget.ramp?.address ?? "");
    latController =
        TextEditingController(text: widget.ramp?.lat.toString() ?? "");
    lonController =
        TextEditingController(text: widget.ramp?.lon.toString() ?? "");
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    latController.dispose();
    lonController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final latText = latController.text.trim();
    final lonText = lonController.text.trim();

    if (name.isEmpty || address.isEmpty || latText.isEmpty || lonText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required.")),
      );
      return;
    }

    final lat = double.tryParse(latText);
    final lon = double.tryParse(lonText);
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Latitude and longitude must be numbers.")),
      );
      return;
    }

    if (widget.isNew) {
      final newRamp = RampLocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        address: address,
        lat: lat,
        lon: lon,
        lanes: 2,
        toilets: false,
        pontoon: false,
        parking: true,
        lighting: false,
        hazards: const [],
        imageUrl: null,
        galleryImages: null,
        geofenceRadius: 100,
        tideStationId: null,
        weatherLocationCode: null,
        adminNotes: null,
      );
      await RampStorageService.upsertRamp(newRamp);
    } else if (widget.ramp != null) {
      final updatedRamp = RampLocation(
        id: widget.ramp!.id,
        name: name,
        address: address,
        lat: lat,
        lon: lon,
        lanes: widget.ramp!.lanes,
        toilets: widget.ramp!.toilets,
        pontoon: widget.ramp!.pontoon,
        parking: widget.ramp!.parking,
        lighting: widget.ramp!.lighting,
        hazards: widget.ramp!.hazards,
        imageUrl: widget.ramp!.imageUrl,
        galleryImages: widget.ramp!.galleryImages,
        geofenceRadius: widget.ramp!.geofenceRadius,
        tideStationId: widget.ramp!.tideStationId,
        weatherLocationCode: widget.ramp!.weatherLocationCode,
        adminNotes: widget.ramp!.adminNotes,
      );
      await RampStorageService.upsertRamp(updatedRamp);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? "Add Ramp" : "Edit Ramp"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Ramp Name"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: "Address"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: "Latitude"),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(labelText: "Longitude"),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async => await _save(),
              icon: const Icon(Icons.save),
              label: Text(widget.isNew ? "Create Ramp" : "Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
