import 'package:flutter/material.dart';

import 'trip_prefs.dart';

class PeopleOnBoardService {
  static const int _min = 1;
  static const int _max = 20;

  static Future<int?> ask({
    required BuildContext context,
    required int currentValue,
    required bool requiredForStart,
  }) async {
    final initial = await TripPrefs.getLastPersonsOnBoard(
      fallback: currentValue > 0 ? currentValue.clamp(_min, _max) : 1,
    );
    if (!context.mounted) return null;

    int value = initial.clamp(_min, _max);

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              requiredForStart ? "People on board" : "People on board",
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: value <= _min
                          ? null
                          : () => setState(() => value = (value - 1).clamp(_min, _max)),
                      icon: const Icon(Icons.remove_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '$value',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton.filled(
                      onPressed: value >= _max
                          ? null
                          : () => setState(() => value = (value + 1).clamp(_min, _max)),
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + or − to change',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, value),
                child: const Text("Done"),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return null;

    if (requiredForStart && result <= 0) return null;

    await TripPrefs.setLastPersonsOnBoard(result);
    await TripPrefs.setPersonsOnBoard(result);
    return result;
  }
}
