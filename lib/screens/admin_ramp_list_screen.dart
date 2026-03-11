import 'package:flutter/material.dart';
import 'admin_edit_ramp_screen.dart';
import '../models/ramp_location.dart';
import '../services/ramp_storage_service.dart';

class AdminRampListScreen extends StatefulWidget {
  const AdminRampListScreen({super.key});

  @override
  State<AdminRampListScreen> createState() => _AdminRampListScreenState();
}

class _AdminRampListScreenState extends State<AdminRampListScreen> {
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
      appBar: AppBar(
        title: const Text("Admin – Manage Ramps"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminEditRampScreen(isNew: true),
            ),
          );
          if (changed == true) {
            _loadRamps();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: ramps.length,
        itemBuilder: (context, index) {
          final r = ramps[index];

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(r.name),
              subtitle: Text(r.address),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminEditRampScreen(ramp: r),
                  ),
                );
                if (changed == true) {
                  _loadRamps();
                }
              },
            ),
          );
        },
      ),
    );
  }
}
