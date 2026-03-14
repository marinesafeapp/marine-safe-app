import 'package:flutter/material.dart';

import 'boat_details_screen.dart';
import 'join_boat_screen.dart';
import 'pro_screen.dart';
import 'safety_equipment_screen.dart';
import 'trip_history_screen.dart';
import '../services/user_profile_service.dart';

/// "Gear" tab: links to boat details, safety equipment, trip history (Pro), Pro, join a boat.
class PrepareScreen extends StatefulWidget {
  const PrepareScreen({super.key});

  @override
  State<PrepareScreen> createState() => _PrepareScreenState();
}

class _PrepareScreenState extends State<PrepareScreen> {
  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);
  /// Darker card background to separate Gear from main app background
  static const Color _cardBg = Color(0xFF030508);
  /// Slightly tinted card for upgrade-related items (free users only)
  static const Color _cardBgVariant = Color(0xFF050A10);

  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _loadPro();
  }

  Future<void> _loadPro() async {
    final isPro = await UserProfileService.instance.getIsPro();
    if (mounted) setState(() => _isPro = isPro);
  }

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
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _isPro
                  ? "Boat details, safety equipment, and trip history."
                  : "Boat details, safety equipment, and trip history (Pro).",
              style: const TextStyle(color: Colors.white70, height: 1.4),
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
          if (_isPro) ...[
            const SizedBox(height: 12),
            _linkCard(
              context,
              icon: Icons.history_rounded,
              title: "Trip history",
              subtitle: "Past trips and logs",
              onTap: () => _push(context, const TripHistoryScreen()),
              variantBackground: false,
              showProBadge: false,
            ),
          ],
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.workspace_premium_rounded,
            title: _isPro ? "Subscription" : "Marine Safe Pro",
            subtitle: _isPro ? "Manage your plan" : "Unlock trip history, multiple vessels, invite crew",
            onTap: () => _push(context, const ProScreen()),
            variantBackground: !_isPro,
            showProBadge: !_isPro,
          ),
          const SizedBox(height: 12),
          _linkCard(
            context,
            icon: Icons.group_add_rounded,
            title: "Join a boat",
            subtitle: "Enter code to view the same trip",
            onTap: () => _push(context, const JoinBoatScreen()),
            variantBackground: !_isPro,
            showProBadge: !_isPro,
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
    bool showProBadge = false,
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
            border: Border.all(color: variantBackground ? _accent.withValues(alpha: 0.18) : Colors.white10),
          ),
          child: ClipRect(
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showProBadge) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _accent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _accent.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                "Pro",
                                style: TextStyle(
                                  color: Color(0xFF2CB6FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (mounted) _loadPro();
    });
  }
}
