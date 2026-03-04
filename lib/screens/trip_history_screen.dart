import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> history = [];

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    history = await LocalStorageService.loadTripHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Trip History"),
      ),
      body: history.isEmpty
          ? const Center(
              child: Text(
                "No trips logged yet.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, i) {
                final item = history[i];
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11161C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item["rampName"] ?? "Unknown",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text("Start: ${item["startTime"]}",
                          style: const TextStyle(color: Colors.white70)),
                      Text("Stop:  ${item["stopTime"]}",
                          style: const TextStyle(color: Colors.white70)),
                      if (item["eta"] != null)
                        Text("ETA:   ${item["eta"]}",
                            style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
