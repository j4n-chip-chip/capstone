import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> initializePersistence() async {
    await _auth.setPersistence(Persistence.LOCAL);
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastLoginAt': FieldValue.serverTimestamp()});
      } catch (_) {
        // Login already succeeded. Do not fail authentication
        // because updating login metadata was unsuccessful.
      }
    }

    return credential;
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'role': 'Farmer',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        try {
          await user.delete();
        } catch (_) {
          // Best-effort rollback.
        }

        rethrow;
      }
    }

    return credential;
  }

  Future<void> resetPassword({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> logout() async {
    try {
      await notificationService.removeTokenForCurrentUser();
    } catch (_) {
      // Logout should still continue if token cleanup fails.
    }

    await _auth.signOut();
  }
}

final firebaseAuthService = FirebaseAuthService();
