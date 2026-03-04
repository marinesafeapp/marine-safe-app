import 'package:flutter/material.dart';

import 'screens/prepare_screen.dart';
import 'screens/home_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sponsors_screen.dart';

/// Main shell with bottom navigation bar (Gear, Forecast, Trip, Profile, Sponsors).
/// Trip is in the middle; Fishing rules are available via FAB on the Trip (home) screen.
class MainShell extends StatefulWidget {
  /// Optional initial tab (0=Gear, 1=Forecast, 2=Trip, 3=Profile, 4=Sponsors). Used e.g. after first-time registration to open Profile.
  final int? initialIndex;

  const MainShell({super.key, this.initialIndex});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    _currentIndex = (idx != null && idx >= 0 && idx <= 4) ? idx : 2; // Default to Trip (middle)
  }

  List<Widget> get _screens => [
    PrepareScreen(),
    WeatherScreen(visible: _currentIndex == 1),
    HomeScreen(currentTabIndex: _currentIndex),
    ProfileScreen(),
    SponsorsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02050A),
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Boat watermark — bigger, lower, softly blended (clipping OK)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 0.06,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: ShaderMask(
                      // Fade the top so it blends behind content.
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white, Colors.white],
                        stops: [0.0, 0.5, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: Transform.translate(
                        offset: const Offset(-60, 90),
                        child: Transform.scale(
                          scale: 1.55,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(-1, 1, 1),
                            child: Image.asset(
                              'assets/images/boat.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.bottomCenter,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF02050A),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.checklist_rounded, 'Gear'),
                _navItem(1, Icons.cloud_rounded, 'Forecast'),
                _navItem(2, Icons.directions_boat_rounded, 'Trip'),
                _navItem(3, Icons.person_rounded, 'Profile'),
                _navItem(4, Icons.business_rounded, 'Sponsors'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    final color = selected ? const Color(0xFF2CB6FF) : Colors.white54;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
