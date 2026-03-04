import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/trip_status.dart';

String formatDurationShort(Duration d) {
  final neg = d.isNegative;
  final dd = neg ? d.abs() : d;
  final h = dd.inHours;
  final m = dd.inMinutes.remainder(60);
  final s = dd.inSeconds.remainder(60);

  String two(int x) => x.toString().padLeft(2, '0');

  if (h > 0) return '${neg ? "-" : ""}${h}h ${two(m)}m';
  return '${neg ? "-" : ""}${two(m)}m ${two(s)}s';
}

Color tripStatusColor(TripStatus status) {
  switch (status) {
    case TripStatus.overdue:
      return Colors.redAccent;
    case TripStatus.dueSoon:
      return Colors.orangeAccent;
    case TripStatus.ok:
      return Colors.greenAccent;
  }
}

/// Professional banner shown ONLY when trip is active + ETA set
class ActiveTripBanner extends StatelessWidget {
  final Color accent;
  final String rampName;
  final DateTime? departAt;
  final DateTime eta;
  final TripStatus status;

  const ActiveTripBanner({
    super.key,
    required this.accent,
    required this.rampName,
    required this.departAt,
    required this.eta,
    required this.status,
  });

  String _time(BuildContext context, DateTime dt) =>
      TimeOfDay.fromDateTime(dt).format(context);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final c = tripStatusColor(status);

    final String line1 = status == TripStatus.overdue
        ? "OVERDUE"
        : status == TripStatus.dueSoon
        ? "DUE SOON"
        : "ON THE WATER";

    // Keep short to avoid pill overflow
    final String line2 = status == TripStatus.overdue
        ? "Overdue ${formatDurationShort(now.difference(eta))}"
        : "In ${formatDurationShort(eta.difference(now))}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == TripStatus.overdue ? Colors.redAccent : Colors.white24,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.withValues(alpha:0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withValues(alpha:0.7)),
            ),
            child: Icon(
              status == TripStatus.overdue ? Icons.warning_rounded : Icons.waves_rounded,
              color: c,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rampName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.start,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _pill("ETA ${_time(context, eta)}", c, Icons.schedule_rounded),
                    if (departAt != null)
                      _pill(
                        "Depart ${_time(context, departAt!)}",
                        Colors.white70,
                        Icons.departure_board_rounded,
                      ),
                    _pill(
                      line2,
                      status == TripStatus.overdue ? Colors.redAccent : Colors.white70,
                      Icons.timer_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(String label, Color color, IconData icon) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260), // prevents long-pill overflow
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha:0.75)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap card to open Manage Trip sheet
class TripActiveManageCard extends StatelessWidget {
  final TripStatus status;
  final VoidCallback onTap;

  const TripActiveManageCard({
    super.key,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = tripStatusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.withValues(alpha:0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withValues(alpha:0.65)),
              ),
              child: Icon(Icons.tune_rounded, color: c),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Manage trip",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
