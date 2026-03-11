import 'package:flutter/material.dart';

import '../models/ramp_location.dart';
import '../services/ramp_storage_service.dart';

class EditRampScreen extends StatefulWidget {
  final RampLocation? existingRamp;

  const EditRampScreen({super.key, this.existingRamp});

  @override
  State<EditRampScreen> createState() => _EditRampScreenState();
}

class _EditRampScreenState extends State<EditRampScreen> {
  final id = TextEditingController();
  final name = TextEditingController();
  final address = TextEditingController();
  final lat = TextEditingController();
  final lon = TextEditingController();

  final imageUrl = TextEditingController();
  final galleryImages = TextEditingController();

  final geofence = TextEditingController();
  final tideStation = TextEditingController();
  final weatherCode = TextEditingController();
  final adminNotes = TextEditingController();

  final hazardsInput = TextEditingController();

  int lanes = 1;
  bool toilets = false;
  bool pontoon = false;
  bool parking = false;
  bool lighting = false;

  @override
  void initState() {
    super.initState();

    final r = widget.existingRamp;
    if (r != null) {
      id.text = r.id;
      name.text = r.name;
      address.text = r.address;
      lat.text = r.lat.toString();
      lon.text = r.lon.toString();

      lanes = r.lanes;
      toilets = r.toilets;
      pontoon = r.pontoon;
      parking = r.parking;
      lighting = r.lighting;

      hazardsInput.text = r.hazards.join(", ");

      imageUrl.text = r.imageUrl ?? "";
      galleryImages.text =
          r.galleryImages?.join(", ") ?? "";
      geofence.text = r.geofenceRadius.toString();
      tideStation.text = r.tideStationId ?? "";
      weatherCode.text = r.weatherLocationCode ?? "";
      adminNotes.text = r.adminNotes ?? "";
    }
  }

  Future<void> _save() async {
    final ramp = RampLocation(
      id: id.text.isEmpty
          ? name.text.toLowerCase().replaceAll(" ", "_")
          : id.text,
      name: name.text,
      address: address.text,
      lat: double.tryParse(lat.text) ?? 0,
      lon: double.tryParse(lon.text) ?? 0,
      lanes: lanes,
      toilets: toilets,
      pontoon: pontoon,
      parking: parking,
      lighting: lighting,
      hazards: hazardsInput.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      imageUrl:
          imageUrl.text.isEmpty ? null : imageUrl.text,
      galleryImages: galleryImages.text.isEmpty
          ? null
          : galleryImages.text
              .split(',')
              .map((e) => e.trim())
              .toList(),
      geofenceRadius:
          double.tryParse(geofence.text) ?? 100,
      tideStationId:
          tideStation.text.isEmpty ? null : tideStation.text,
      weatherLocationCode:
          weatherCode.text.isEmpty ? null : weatherCode.text,
      adminNotes:
          adminNotes.text.isEmpty ? null : adminNotes.text,
    );

    await RampStorageService.upsertRamp(ramp);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.existingRamp == null
              ? "Add Ramp"
              : "Edit Ramp",
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            field("Ramp ID (auto if empty)", id),
            field("Ramp Name", name),
            field("Address", address),
            field("Latitude", lat),
            field("Longitude", lon),

            numberField("Lanes", lanes),

            toggle("Toilets", toilets,
                (v) => setState(() => toilets = v)),
            toggle("Pontoon", pontoon,
                (v) => setState(() => pontoon = v)),
            toggle("Parking", parking,
                (v) => setState(() => parking = v)),
            toggle("Lighting", lighting,
                (v) => setState(() => lighting = v)),

            field("Hazards (comma separated)", hazardsInput),

            field("Image URL", imageUrl),
            field("Gallery URLs (comma separated)",
                galleryImages),

            field("Geofence Radius (meters)", geofence),
            field("Tide Station ID", tideStation),
            field("Weather Location Code", weatherCode),

            field("Admin Notes", adminNotes),

            const SizedBox(height: 20),
            saveButton(),
          ],
        ),
      ),
    );
  }

  Widget field(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF11161C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Widget numberField(String label, int val) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 16),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove,
              color: Colors.white),
          onPressed: () => setState(
              () => lanes = (lanes - 1).clamp(1, 10)),
        ),
        Text(
          "$lanes",
          style: const TextStyle(
              color: Colors.white, fontSize: 18),
        ),
        IconButton(
          icon:
              const Icon(Icons.add, color: Colors.white),
          onPressed: () => setState(
              () => lanes = (lanes + 1).clamp(1, 10)),
        ),
      ],
    );
  }

  Widget toggle(
      String label, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title:
          Text(label, style: const TextStyle(color: Colors.white)),
      value: value,
      activeThumbColor: Colors.blueAccent,
      onChanged: onChanged,
      tileColor: const Color(0xFF11161C),
    );
  }

  Widget saveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 50),
      ),
      onPressed: _save,
      child: const Text("Save Ramp"),
    );
  }
}
