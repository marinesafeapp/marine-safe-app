import 'package:flutter/material.dart';
import '../home_widgets.dart';

class EtaCard extends StatelessWidget {
  final Color accent;
  final bool tripActive;

  final bool isOverdue;
  final bool isApproaching;

  final String etaCardText;

  final VoidCallback onPickEta;
  final VoidCallback? onExtend30m;
  final VoidCallback? onExtend1h;

  const EtaCard({
    super.key,
    required this.accent,
    required this.tripActive,
    required this.isOverdue,
    required this.isApproaching,
    required this.etaCardText,
    required this.onPickEta,
    required this.onExtend30m,
    required this.onExtend1h,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 18,
                color: isOverdue ? Colors.redAccent : accent,
              ),
              const SizedBox(width: 10),
              Text(
                isOverdue ? "RETURN ETA (OVERDUE)" : "RETURN ETA",
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w900,
                  color: isOverdue ? Colors.redAccent : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          valueText(
            etaCardText,
            color: isOverdue ? Colors.redAccent : Colors.white,
          ),

          if (tripActive && isApproaching) ...[
            const SizedBox(height: 10),
            Text(
              "⏰ Due in 30 minutes — extend now if you’re running late.",
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha:0.9),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: primaryButton(accent),
              onPressed: onPickEta,
              child: Text(tripActive ? "Change ETA" : "Set ETA"),
            ),
          ),

          if (tripActive && onExtend30m != null && onExtend1h != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onExtend30m,
                    style: outlineButton(accent),
                    child: const Text("Extend 30m"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onExtend1h,
                    style: outlineButton(accent),
                    child: const Text("Extend 1h"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
