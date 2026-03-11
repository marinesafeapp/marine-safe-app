import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Alias imports so HomeTripState can NEVER collide
import 'package:flutter_application_1/screens/home/controller/home_controller.dart' as hc;
import 'package:flutter_application_1/screens/home/models/home_trip_state.dart' as hts;

import 'package:flutter_application_1/screens/can_we_fish_here_screen.dart';
import 'package:flutter_application_1/screens/fishing_rules_screen.dart';
import 'package:flutter_application_1/screens/tides_screen.dart';
import 'package:flutter_application_1/screens/home/services/exact_alarm_permission_service.dart';
import 'package:flutter_application_1/screens/home/services/emergency_sms_service.dart';
import 'package:flutter_application_1/screens/home/widgets/ramp_card.dart';
import 'package:flutter_application_1/screens/home/widgets/eta_card.dart';
import 'package:flutter_application_1/screens/home/widgets/start_end_trip_button.dart';
import 'package:flutter_application_1/screens/home/widgets/trip_active_widgets.dart';
import 'package:flutter_application_1/screens/home/services/battery_optimisation_service.dart';
import 'package:flutter_application_1/services/notifications/notification_bootstrap.dart';
import 'package:flutter_application_1/services/trip/trip_escalation_service.dart';

/// Trip tab index in MainShell bottom nav.
const int _kTripTabIndex = 2;

class HomeScreen extends StatefulWidget {
  final int currentTabIndex;

  const HomeScreen({super.key, this.currentTabIndex = _kTripTabIndex});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final hc.HomeController controller = hc.HomeController();

  final Color _accent = const Color(0xFF2CB6FF);

  bool _overdueDialogQueued = false;

  static const Color _bg = Color(0xFF02050A);
  static const Color _bgBottom = Color(0xFF050d18);

  @override
  void initState() {
    super.initState();

    // ✅ kick off controller lifecycle AFTER first build frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await controller.init(context);
      if (!mounted) return;
      // Refresh ramp list so postcode filter is applied
      await controller.refreshRampsForSelection();
      if (!mounted) return;
      await ExactAlarmPermissionService.ensureExactAlarmsEnabled(context);
      if (!mounted) return;
      await controller.showSafetyDisclaimerIfNeeded(context);
      if (!mounted) return;

      // ✅ Android battery optimisation warning (one-time)
      await BatteryOptimisationService.showIfNeeded(context);

      if (!mounted) return;
      await _handlePendingEscalationAction(context);

      if (!mounted) return;
      setState(() {});
    });
  }

  /// If user tapped ETA+10 or ETA+20 notification, open SMS to primary contact.
  Future<void> _handlePendingEscalationAction(BuildContext context) async {
    final p = await SharedPreferences.getInstance();
    final action = p.getString(kPendingEscalationActionKey);
    if (action == null || action.isEmpty) return;
    await p.remove(kPendingEscalationActionKey);
    if (!context.mounted) return;
    if (action == TripEscalationService.payloadSmsPrimary ||
        action == TripEscalationService.payloadSmsAll) {
      await EmergencySmsService.openEscalationSmsToPrimaryContact(context);
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When user switches to Trip tab, refresh ramp list (closest ramps within 200 km of postcode)
    if (oldWidget.currentTabIndex != _kTripTabIndex && widget.currentTabIndex == _kTripTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _handlePendingEscalationAction(context);
        if (!mounted) return;
        // Short delay so Profile's postcode save has time to commit to prefs
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        await controller.refreshRampsForSelection();
      });
    }
  }

  @override
  void dispose() {
    // ✅ Only dispose once (controller.dispose() also calls disposeController())
    controller.dispose();
    super.dispose();
  }

  void _maybeQueueOverdueDialog(hts.HomeTripState s) {
    final shouldShow = s.isOverdue && !s.overdueAcknowledged;
    if (!shouldShow) {
      _overdueDialogQueued = false;
      return;
    }

    if (_overdueDialogQueued) return;
    _overdueDialogQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await controller.showOverdueDialogIfNeeded(context);

      final ss = controller.state;
      if (!(ss.isOverdue && !ss.overdueAcknowledged)) {
        _overdueDialogQueued = false;
      }
    });
  }

  String _formatTime(BuildContext context, DateTime dt) {
    final t = TimeOfDay.fromDateTime(dt);
    return t.format(context);
  }

  BoxDecoration _cardDeco({Color? borderColor, double opacity = 0.35}) {
    return BoxDecoration(
      color: Colors.black.withValues(alpha:opacity),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: borderColor ?? _accent.withValues(alpha:0.12),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha:0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _statusStrip(bool tripActive) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: tripActive
            ? _accent.withValues(alpha:0.12)
            : Colors.white.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tripActive ? _accent.withValues(alpha:0.35) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            tripActive ? Icons.waves_rounded : Icons.directions_boat_rounded,
            color: tripActive ? _accent : Colors.white54,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            tripActive ? "Trip in progress" : "Ready to go",
            style: TextStyle(
              color: tripActive ? _accent : Colors.white70,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onChange,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(borderColor: Colors.white24),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha:0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha:0.45)),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
          const SizedBox(width: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onChange,
            child: const Text(
              "Change",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final s = controller.state;
        _maybeQueueOverdueDialog(s);

        return Scaffold(
          key: _scaffoldKey,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bg, _bg, _bgBottom],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    titleSpacing: 12,
                    title: Row(
                      children: [
                        Image.asset(
                          'assets/branding/marine_safe_logo_icon.png',
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Marine Safe",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusStrip(s.tripActive && s.eta != null),
                          // TRIP ACTIVE MODE
                          if (s.tripActive && s.eta != null) ...[
                            ActiveTripBanner(
                              accent: _accent,
                              rampName: s.selectedRamp?.name ?? "Selected ramp",
                              departAt: s.departAt,
                              eta: s.eta!,
                              status: s.tripStatus,
                            ),
                            const SizedBox(height: 12),
                            TripActiveManageCard(
                              status: s.tripStatus,
                              onTap: () => controller.openManageTripSheet(context),
                            ),
                            const SizedBox(height: 12),
                            if (s.isOverdue && !s.overdueAcknowledged) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent.withValues(alpha:0.30),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: () => controller.acknowledgeOverdue(context),
                                  icon: const Icon(Icons.warning_rounded),
                                  label: const Text(
                                    "ACKNOWLEDGE OVERDUE",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            StartEndTripButton(
                              tripActive: s.tripActive,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("End trip?"),
                                    content: const Text(
                                      "Your trip will be marked as ended. You can start a new trip anytime.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text("End trip"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await controller.endTrip();
                                }
                              },
                            ),
                          ]
                          // IDLE MODE
                          else ...[
                            if (s.selectedRamp == null) ...[
                              RampCard(
                                accent: _accent,
                                tripActive: s.tripActive,
                                selectedRamp: s.selectedRamp,
                                favouriteRamps: controller.favouriteRamps,
                                isSelectedFavourite: false,
                                onToggleFavouriteSelected: null,
                                confirmChangeRamp: () async => true,
                                onRampSelected: (r) async {
                                  await controller.setRamp(r);
                                },
                                onNearMe: () async {
                                  await controller.selectNearestRampByLocation(context);
                                },
                                ramps: controller.rampsForSelection,
                                rampListSubtitle: controller.rampListSubtitle,
                              ),
                            ] else ...[
                              _compactCard(
                                icon: Icons.anchor_rounded,
                                title: "Launch ramp",
                                value: s.selectedRamp!.name,
                                trailing: IconButton(
                                  tooltip: controller.isFavouriteRamp(s.selectedRamp!.id)
                                      ? "Unfavourite"
                                      : "Favourite",
                                  onPressed: () async {
                                    await controller.toggleFavouriteRamp(s.selectedRamp!);
                                  },
                                  icon: Icon(
                                    controller.isFavouriteRamp(s.selectedRamp!.id)
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: controller.isFavouriteRamp(s.selectedRamp!.id)
                                        ? Colors.amber
                                        : Colors.white70,
                                  ),
                                ),
                                onChange: () async => controller.clearRamp(),
                              ),
                            ],
                            const SizedBox(height: 14),
                            if (s.eta == null) ...[
                              EtaCard(
                                accent: _accent,
                                tripActive: s.tripActive,
                                isOverdue: s.isOverdue,
                                isApproaching: s.isApproaching,
                                etaCardText: s.etaCardText,
                                onPickEta: () => controller.pickEta(context),
                                onExtend30m: null,
                                onExtend1h: null,
                              ),
                            ] else ...[
                              _compactCard(
                                icon: Icons.schedule_rounded,
                                title: "Return ETA",
                                value: _formatTime(context, s.eta!),
                                onChange: () async => controller.clearEta(),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // Hint when idle
                            if (!s.tripActive && s.selectedRamp != null && s.eta != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  "All set — start your trip when you launch.",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            StartEndTripButton(
                              tripActive: s.tripActive,
                              onPressed: () async {
                                if (s.tripActive) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("End trip?"),
                                      content: const Text(
                                        "Your trip will be marked as ended. You can start a new trip anytime.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text("End trip"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && mounted) {
                                    await controller.endTrip();
                                  }
                                } else {
                                  await controller.startTrip(context);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  _QuickActionsBar(accent: _accent),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom bar with quick actions: Tide times, Can we fish here?, Fishing rules.
class _QuickActionsBar extends StatelessWidget {
  final Color accent;

  const _QuickActionsBar({required this.accent});

  void _open(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _ActionChip(
              icon: Icons.waves_rounded,
              label: 'Tide times',
              accent: accent,
              onPressed: () => _open(context, const TidesScreen()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionChip(
              icon: Icons.location_on_rounded,
              label: 'Fish here?',
              accent: accent,
              onPressed: () => _open(context, const CanWeFishHereScreen()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionChip(
              icon: Icons.gavel_rounded,
              label: 'Rules',
              accent: accent,
              onPressed: () => _open(context, const FishingRulesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact button for the top quick-actions bar.
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
