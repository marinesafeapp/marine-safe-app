import 'package:flutter/foundation.dart';

/// Placeholder model for a future "Licences & Permits" section.
///
/// Kept intentionally lightweight for now so it can be extended later
/// without refactoring the rest of the app.
@immutable
class LicencesPermitsState {
  final List<LicencePermitItem> items;

  const LicencesPermitsState({
    this.items = const <LicencePermitItem>[],
  });

  const LicencesPermitsState.empty() : items = const <LicencePermitItem>[];
}

@immutable
class LicencePermitItem {
  /// Stable id for the item.
  final String id;

  /// Human-readable title (e.g. "Boating licence", "Fishing licence").
  final String title;

  /// Optional expiry date.
  final DateTime? expiresAt;

  const LicencePermitItem({
    required this.id,
    required this.title,
    this.expiresAt,
  });
}

