import 'package:flutter/material.dart';

import '../screens/home/models/home_trip_state.dart';

/// Placeholder for a future optional Marine Safe Pro "pre-start checklist".
///
/// For now it performs no UI and always returns immediately.
class ProPreStartChecklistService {
  ProPreStartChecklistService._();
  static final ProPreStartChecklistService instance = ProPreStartChecklistService._();

  Future<void> maybeRunChecklist({
    required BuildContext context,
    required HomeTripState tripState,
  }) async {
    // Intentionally empty: scaffolding only.
    // Future work can show a Pro-only checklist before the trip becomes active.
  }
}

