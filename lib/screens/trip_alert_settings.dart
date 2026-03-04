import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripAlertSettings extends StatefulWidget {
  const TripAlertSettings({super.key});

  @override
  State<TripAlertSettings> createState() => _TripAlertSettingsState();
}

class _TripAlertSettingsState extends State<TripAlertSettings> {
  bool popups = true;
  bool sound = true;
  bool vibration = true;
  bool geofence = true;
  bool etaReminders = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      popups = prefs.getBool("popups") ?? true;
      sound = prefs.getBool("sound") ?? true;
      vibration = prefs.getBool("vibration") ?? true;
      geofence = prefs.getBool("geofence") ?? true;
      etaReminders = prefs.getBool("etaReminders") ?? true;
    });
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setBool("popups", popups);
    prefs.setBool("sound", sound);
    prefs.setBool("vibration", vibration);
    prefs.setBool("geofence", geofence);
    prefs.setBool("etaReminders", etaReminders);
  }

  Widget buildSwitch(String title, bool value, Function(bool) onChanged) {
    return Card(
      color: const Color(0xFF043B63),
      child: SwitchListTile(
        activeThumbColor: Colors.greenAccent,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        value: value,
        onChanged: (val) {
          onChanged(val);
          saveSettings();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Alert Settings"),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildSwitch("Pop-up Alerts", popups, (v) => setState(() => popups = v)),
          buildSwitch("Sound Alerts", sound, (v) => setState(() => sound = v)),
          buildSwitch("Vibration Alerts", vibration, (v) => setState(() => vibration = v)),
          buildSwitch("Geofence Alerts", geofence, (v) => setState(() => geofence = v)),
          buildSwitch("Return ETA Reminders", etaReminders, (v) => setState(() => etaReminders = v)),
        ],
      ),
    );
  }
}
