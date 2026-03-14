import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/ramps_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/boat_details_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/safety_equipment_screen.dart';
import 'services/user_profile_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _isPro = false;

  final screens = const [
    HomeScreen(),
    RampsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPro();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPro();
  }

  Future<void> _loadPro() async {
    final isPro = await UserProfileService.instance.getIsPro();
    if (mounted) setState(() => _isPro = isPro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Marine Safe"),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF11161C),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.black),
              child: Center(
                child: Text(
                  "Marine Safe",
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),

            drawerItem(
              icon: Icons.person,
              label: "My Profile",
              screen: const ProfileScreen(),
            ),

            drawerItem(
              icon: Icons.directions_boat,
              label: "My Boat Details",
              screen: const BoatDetailsScreen(),
            ),

            drawerItem(
              icon: Icons.contacts,
              label: "Emergency Contacts",
              screen: const EmergencyContactsScreen(),
            ),

            drawerItem(
              icon: Icons.health_and_safety,
              label: "Safety Equipment",
              screen: const SafetyEquipmentScreen(),
            ),

            if (_isPro)
              drawerItem(
                icon: Icons.history,
                label: "Trip History",
                screen: const TripHistoryScreen(),
              ),

            drawerItem(
              icon: Icons.settings,
              label: "Settings",
              screen: const SettingsScreen(),
            ),
          ],
        ),
      ),

      backgroundColor: Colors.black,
      body: screens[_index],

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Ramps"),
        ],
      ),
    );
  }

  Widget drawerItem({
    required IconData icon,
    required String label,
    required Widget screen,
  }) {
    return ListTile(
      iconColor: Colors.white70,
      textColor: Colors.white,
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ).then((_) {
          if (mounted) _loadPro();
        });
      },
    );
  }
}
