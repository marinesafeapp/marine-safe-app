import 'package:flutter/material.dart';

BoxDecoration glassCard() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha:0.06),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha:0.10)),
  );
}

ButtonStyle primaryButton(Color accent) {
  return ElevatedButton.styleFrom(
    backgroundColor: accent.withValues(alpha:0.22),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

ButtonStyle outlineButton(Color accent) {
  return OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: BorderSide(color: accent.withValues(alpha:0.6)),
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

Widget sectionTitle(Color accent, IconData icon, String title) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha:0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha:0.28)),
        ),
        child: Icon(icon, size: 18, color: accent),
      ),
      const SizedBox(width: 10),
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w900,
          color: Colors.white70,
        ),
      ),
    ],
  );
}

Widget valueText(String text, {Color? color}) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: color ?? Colors.white,
    ),
  );
}
