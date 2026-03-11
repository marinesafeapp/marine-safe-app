import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/fix_issue_router.dart';
import '../../services/reliability/reliability_check_service.dart';

/// Minimal UI to ensure overdue alerts work when the app is closed.
/// Notifications must be granted to continue; battery and exact alarms are recommended.
class ReliabilityCheckScreen extends StatefulWidget {
  const ReliabilityCheckScreen({
    super.key,
    this.showContinueButton = true,
  });

  /// Whether to show the Continue button. Set false when opened from Settings.
  final bool showContinueButton;

  @override
  State<ReliabilityCheckScreen> createState() => _ReliabilityCheckScreenState();
}

class _ReliabilityCheckScreenState extends State<ReliabilityCheckScreen>
    with WidgetsBindingObserver {
  final ReliabilityCheckService _service = ReliabilityCheckService.instance;
  ReliabilityStatus _status = ReliabilityStatus(notificationsGranted: false);
  bool _loading = true;

  static const Color _bg = Color(0xFF02050A);
  static const Color _accent = Color(0xFF2CB6FF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      // Re-check after a short delay; iOS can update permission state slightly after resume.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final status = await _service.check();
    if (mounted) {
      setState(() {
        _status = status;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text(
          "Alert Reliability",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "To make sure overdue alerts work when the app is closed, please check the following:",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _requirementRow(
                    label: "Notifications enabled",
                    ok: _status.notificationsGranted,
                    onAction: () async {
                      // Request permission first (shows in-app dialog on iOS / Android 13+).
                      await _service.requestNotificationsPermission();
                      if (!mounted) return;
                      await _refresh();
                      if (!mounted) return;
                      final statusNow = await _service.check();
                      // If still not granted, open app settings so user can enable there.
                      if (!statusNow.notificationsGranted && mounted) {
                        final issue = Platform.isAndroid
                            ? FixIssue.notificationPermissionDenied
                            : FixIssue.notificationsDisabled;
                        await FixIssueRouter.openFix(issue);
                        if (mounted) await _refresh();
                      }
                      // Staggered refresh so we pick up permission when OS updates (e.g. iOS).
                      for (final delay in [400, 1000]) {
                        await Future.delayed(Duration(milliseconds: delay));
                        if (mounted) await _refresh();
                      }
                    },
                    actionLabel: _status.notificationsGranted
                        ? "Open settings"
                        : "Allow notifications",
                  ),

                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    _requirementRow(
                      label: "Battery: Unrestricted / not optimised",
                      ok: _status.batteryOptimizationDisabled == true,
                      unknown: _status.batteryOptimizationDisabled == null,
                      onAction: () async {
                        await FixIssueRouter.openFix(FixIssue.batteryOptimizationEnabled);
                        if (mounted) _refresh();
                      },
                      actionLabel: "Fix",
                    ),
                    const SizedBox(height: 16),
                    _requirementRow(
                      label: "Alarms & reminders allowed",
                      ok: _status.exactAlarmsAllowed == true,
                      unknown: _status.exactAlarmsAllowed == null,
                      onAction: () async {
                        await FixIssueRouter.openFix(FixIssue.exactAlarmsDisabled);
                        if (mounted) _refresh();
                      },
                      actionLabel: "Fix",
                    ),
                  ],

                  if (widget.showContinueButton && _status.notificationsGranted) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (context.mounted) Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Continue",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _requirementRow({
    required String label,
    required bool ok,
    bool unknown = false,
    required VoidCallback onAction,
    required String actionLabel,
  }) {
    final icon = ok
        ? Icons.check_circle_rounded
        : (unknown ? Icons.help_outline_rounded : Icons.warning_amber_rounded);
    final iconColor = ok
        ? Colors.greenAccent
        : (unknown ? Colors.amber : Colors.orangeAccent);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
