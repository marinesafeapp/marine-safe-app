import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileCloudService {
  static Future<void> saveMyProfile({
    required String displayName,
    required String email,
    required String phone,
    required String emergencyName,
    required String emergencyPhone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Not logged in");
    }

    final now = DateTime.now();

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await ref.set({
      'uid': user.uid,
      'displayName': displayName,
      'email': email,
      'phone': phone,
      'emergencyName': emergencyName,
      'emergencyPhone': emergencyPhone,
      'updatedAt': now.toIso8601String(),
      'updatedAtMs': now.millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }
}
