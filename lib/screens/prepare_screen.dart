import 'package:flutter/material.dart';

import 'boat_details_screen.dart';
import 'join_boat_screen.dart';
import 'pro_screen.dart';
import 'safety_equipment_screen.dart';
import 'trip_history_screen.dart';

/// "Gear" tab: links to boat details, safety equipment, trip history.
class PrepareScreen extends StatelessWidget {
  const PrepareScreen({super.key});

  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  /// Darker card background to separate Gear from main app background
  static const Color _cardBg = Color(0xFF030508);
  /// Background for Pro / Join a boat cards (slightly blue-tinted to distinguish)
  static const Color _cardBgVariant = Color(0xFF06101A);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          "Gear",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomPad),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              "Boat details, safety equipment, and trip history.",
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          _linkCard(
            context,
            icon: Icons.directions_boat_rounded,
            title: "Boat details",
            subtitle: "Registration, EPIRB, flares, extinguisher",
            onTap: () => _push(context, const BoatDetailsScreen()),
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.health_and_safety_rounded,
            title: "Safety equipment",
            subtitle: "PFDs and safety gear",
            onTap: () => _push(context, const SafetyEquipmentScreen()),
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.history_rounded,
            title: "Trip history",
            subtitle: "Past trips and logs",
            onTap: () => _push(context, const TripHistoryScreen()),
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.workspace_premium_rounded,
            title: "Marine Safe Pro",
            subtitle: "Multiple vessels, invite crew",
            onTap: () => _push(context, const ProScreen()),
            variantBackground: true,
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.group_add_rounded,
            title: "Join a boat",
            subtitle: "Enter code to view the same trip",
            onTap: () => _push(context, const JoinBoatScreen()),
            variantBackground: true,
          ),
        ],
      ),
    );
  }

  Widget _linkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool variantBackground = false,
  }) {
    final cardColor = variantBackground ? _cardBgVariant : _cardBg;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: variantBackground ? _accent.withValues(alpha: 0.25) : Colors.white12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha:0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accent.withValues(alpha:0.45)),
                ),
                child: Icon(icon, color: _accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
