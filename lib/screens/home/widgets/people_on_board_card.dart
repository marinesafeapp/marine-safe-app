import 'package:flutter/material.dart';

class PeopleOnBoardCard extends StatelessWidget {
  final bool tripActive;
  final int personsOnBoard;
  final VoidCallback onEdit;

  const PeopleOnBoardCard({
    super.key,
    required this.tripActive,
    required this.personsOnBoard,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = tripActive ? Colors.greenAccent : Colors.white70;

    return Container(
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
                color: accent.withValues(alpha:0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha:0.6)),
              ),
              child: Icon(Icons.groups_rounded, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "People on board",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$personsOnBoard",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Edit",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
    );
  }
}
