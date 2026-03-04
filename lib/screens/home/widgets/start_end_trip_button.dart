import 'package:flutter/material.dart';

/// App accent used for "Start trip" to match branding
const Color _startTripAccent = Color(0xFF2CB6FF);

class StartEndTripButton extends StatelessWidget {
  final bool tripActive;
  final VoidCallback onPressed;

  const StartEndTripButton({
    super.key,
    required this.tripActive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = tripActive ? Colors.redAccent : _startTripAccent;
    final IconData icon = tripActive ? Icons.stop_circle_rounded : Icons.play_circle_rounded;
    final String text = tripActive ? "END TRIP" : "START TRIP";

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 26),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: color.withValues(alpha:0.45),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
