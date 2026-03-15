import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/user_profile_service.dart';
import 'pro_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> history = [];
  bool? _isPro;

  @override
  void initState() {
    super.initState();
    _checkPro();
  }

  Future<void> _checkPro() async {
    final isPro = await UserProfileService.instance.getIsPro();
    if (mounted) setState(() => _isPro = isPro);
    if (isPro) loadHistory();
  }

  Future<void> loadHistory() async {
    final list = await LocalStorageService.loadTripHistory();
    if (mounted) {
      setState(() => history = list);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPro == false) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Trip History"),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'Trip History is a Pro feature.',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upgrade to Pro to view your past trips.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProScreen()),
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Marine Safe Pro'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2CB6FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Trip History"),
      ),
      body: _isPro == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB6FF)))
          : history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.directions_boat, size: 64, color: Colors.white24),
                    SizedBox(height: 16),
                    Text(
                      'No trips logged yet.',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'On the Home tab: select a ramp, set your return ETA, tap START TRIP, then when you finish tap END TRIP and confirm. The trip will appear here.',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadHistory,
              color: Colors.white,
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, i) {
                  final item = history[i];
                  final startTime = item["startTime"]?.toString() ?? "—";
                  final stopTime = item["stopTime"]?.toString() ?? "—";
                  final eta = item["eta"]?.toString();
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
                        Text("Start: $startTime",
                            style: const TextStyle(color: Colors.white70)),
                        Text("Stop:  $stopTime",
                            style: const TextStyle(color: Colors.white70)),
                        if (eta != null)
                          Text("ETA:   $eta",
                              style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
