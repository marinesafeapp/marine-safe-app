import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emergency_contact.dart';
import '../screens/home/models/home_trip_state.dart';
import 'emergency_contact_service.dart';
import 'user_profile_service.dart';

class TripCloudService {
  TripCloudService._();
  static final TripCloudService instance = TripCloudService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _joinCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _joinCodeLength = 6;
  static const String _tripCodesCollection = 'tripCodes';

  /// Always use the signed-in user's UID as doc id
  String _docId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return 'anonymous';
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _doc() => _db.collection('trips').doc(_docId());

  String _generateJoinCode() {
    final r = Random();
    return List.generate(_joinCodeLength, (_) => _joinCodeChars[r.nextInt(_joinCodeChars.length)]).join();
  }

  bool _calcIsOverdue(HomeTripState s) {
    if (!s.tripActive) return false;
    if (s.eta == null) return false;
    if (s.overdueAcknowledged) return false;
    return DateTime.now().isAfter(s.eta!);
  }

  /// BEST name priority:
  /// 1) locally saved profile name (forced by name dialog)
  /// 2) Firebase displayName
  /// 3) email prefix
  Future<String> _bestUserName() async {
    final fromProfile = await UserProfileService.instance.getUserName();
    if (fromProfile != null && fromProfile.trim().isNotEmpty) return fromProfile.trim();

    final u = _auth.currentUser;
    if (u == null) return 'Unnamed User';

    final dn = (u.displayName ?? '').trim();
    if (dn.isNotEmpty) return dn;

    final email = (u.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;

    return 'Unnamed User';
  }

  /// Build emergency contacts snapshot for server-side SMS escalation (E.164, isPrimary).
  Future<List<Map<String, dynamic>>> _getEmergencyContactsSnapshot() async {
    try {
      final list = await EmergencyContactService.loadContacts();
      final out = <Map<String, dynamic>>[];
      for (int i = 0; i < list.length; i++) {
        final c = list[i];
        final e164 = c.phoneE164;
        if (e164.isEmpty) continue;
        out.add({
          'name': c.name,
          'phoneE164': e164,
          'isPrimary': i == 0,
        });
      }
      if (out.isEmpty) {
        final profile = await _db.collection('users').doc(_docId()).get();
        final d = profile.data();
        final name = (d?['emergencyName'] ?? '').toString().trim();
        final phone = (d?['emergencyPhone'] ?? '').toString().trim();
        if (name.isNotEmpty && phone.isNotEmpty) {
          final e164 = phoneToE164(phone);
          if (e164.isNotEmpty) {
            out.add({'name': name, 'phoneE164': e164, 'isPrimary': true});
          }
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> upsertFromState(HomeTripState s) async {
    final u = _auth.currentUser;
    final now = DateTime.now();
    final name = await _bestUserName();

    final data = <String, dynamic>{
      // Identity
      'uid': u?.uid ?? '',
      'name': name,
      'email': (u?.email ?? '').toString(),

      // Trip state
      'tripActive': s.tripActive,
      'active': s.tripActive,
      'departAtIso': s.departAt?.toIso8601String() ?? '',
      'etaIso': s.eta?.toIso8601String() ?? '',
      'etaUtc': s.eta != null ? Timestamp.fromDate(s.eta!) : null,
      'rampId': s.selectedRamp?.id ?? '',
      'rampName': s.selectedRamp?.name ?? '',
      'personsOnBoard': s.personsOnBoard,

      // Overdue (only set when trip active so we don't clear server/ended state)
      'overdueAcknowledged': s.overdueAcknowledged,
      'isOverdue': _calcIsOverdue(s),
      if (s.tripActive) 'acknowledgedAtUtc': s.overdueAcknowledged ? FieldValue.serverTimestamp() : null,
      if (s.tripActive) 'endedAtUtc': null,

      // Updated
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': now.millisecondsSinceEpoch,
    };

    if (s.tripActive && s.eta != null) {
      data['emergencyContacts'] = await _getEmergencyContactsSnapshot();
    }

    if (s.tripActive && s.personsOnBoard > 1) {
      final snap = await _doc().get();
      final existingCode = snap.data()?['joinCode'] as String?;
      final expiresAt = (snap.data()?['joinCodeExpiresAt'] as Timestamp?)?.toDate();
      final isOverdue = _calcIsOverdue(s);
      final rampName = s.selectedRamp?.name ?? '';
      final etaIso = s.eta?.toIso8601String() ?? '';
      final expiresAtDate = s.eta != null && s.eta!.isAfter(DateTime.now())
          ? s.eta!.add(const Duration(hours: 2))
          : DateTime.now().add(const Duration(hours: 24));
      final summary = <String, dynamic>{
        'uid': _docId(),
        'name': name,
        'rampName': rampName,
        'etaIso': etaIso,
        'isOverdue': isOverdue,
        'tripActive': true,
        'expiresAt': Timestamp.fromDate(expiresAtDate),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingCode == null || existingCode.length != _joinCodeLength || expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        if (existingCode != null && existingCode.length == _joinCodeLength) {
          await _db.collection(_tripCodesCollection).doc(existingCode).delete();
        }
        final joinCode = _generateJoinCode();
        data['joinCode'] = joinCode;
        data['joinCodeExpiresAt'] = Timestamp.fromDate(expiresAtDate);
        await _db.collection(_tripCodesCollection).doc(joinCode).set(summary);
      } else {
        data['joinCode'] = existingCode;
        data['joinCodeExpiresAt'] = Timestamp.fromDate(expiresAtDate);
        await _db.collection(_tripCodesCollection).doc(existingCode).set(summary, SetOptions(merge: true));
      }
    } else {
      final snap = await _doc().get();
      final oldCode = snap.data()?['joinCode'] as String?;
      if (oldCode != null && oldCode.length == _joinCodeLength) {
        await _db.collection(_tripCodesCollection).doc(oldCode).delete();
      }
      data['joinCode'] = null;
      data['joinCodeExpiresAt'] = null;
    }

    await _doc().set(data, SetOptions(merge: true));
  }

  /// Call once when user starts a trip so server can send ETA+30/+40 SMS (resets markers).
  Future<void> resetEscalationMarkers() async {
    await _doc().set({
      'primarySmsSentAtUtc': null,
      'allSmsSentAtUtc': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  /// Call when user taps "I'm Safe" so server stops escalation immediately.
  Future<void> setAcknowledged() async {
    await _doc().set({
      'acknowledgedAtUtc': FieldValue.serverTimestamp(),
      'overdueAcknowledged': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<void> markEnded() async {
    final u = _auth.currentUser;
    final now = DateTime.now();
    final name = await _bestUserName();

    await _doc().set({
      'uid': u?.uid ?? '',
      'name': name,
      'email': (u?.email ?? '').toString(),

      'tripActive': false,
      'active': false,
      'departAtIso': '',
      'etaIso': '',
      'etaUtc': null,
      'rampId': '',
      'rampName': '',
      'personsOnBoard': 0,

      'overdueAcknowledged': false,
      'isOverdue': false,
      'endedAtUtc': FieldValue.serverTimestamp(),
      'joinCode': null,
      'joinCodeExpiresAt': null,

      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': now.millisecondsSinceEpoch,
    }, SetOptions(merge: true));

    final snap = await _doc().get();
    final joinCode = snap.data()?['joinCode'] as String?;
    if (joinCode != null && joinCode.length == _joinCodeLength) {
      await _db.collection(_tripCodesCollection).doc(joinCode).delete();
    }
  }

  /// When trip is active and personsOnBoard > 1, get or create a 6-char join code so crew can log on to same boat.
  Future<String?> getOrCreateJoinCode(HomeTripState s) async {
    if (!s.tripActive || s.personsOnBoard <= 1) return null;
    await upsertFromState(s);
    final snap = await _doc().get();
    final joinCode = snap.data()?['joinCode'] as String?;
    if (joinCode != null && joinCode.length == _joinCodeLength) return joinCode;
    return null;
  }

  /// Look up trip by crew join code. Returns trip summary (rampName, etaIso, etc.) from tripCodes only; no read of trips collection.
  Future<Map<String, dynamic>?> lookupTripByCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length != _joinCodeLength) return null;
    final codeDoc = await _db.collection(_tripCodesCollection).doc(trimmed).get();
    if (!codeDoc.exists) return null;
    final data = codeDoc.data();
    if (data == null) return null;
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) return null;
    final active = data['tripActive'] as bool?;
    if (active != true) return null;
    return data;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> tripsStream() {
    return _db.collection('trips').orderBy('updatedAtMs', descending: true).snapshots();
  }
}
