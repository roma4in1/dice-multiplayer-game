import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in anonymously — with Safari/ITP-safe persistence fallback
  Future<User?> signInAnonymously() async {
    if (kIsWeb) {
      // Safari's ITP blocks IndexedDB; try LOCAL first, fall back to SESSION, then NONE
      for (final p in [Persistence.LOCAL, Persistence.SESSION, Persistence.NONE]) {
        try {
          await _auth.setPersistence(p);
          break;
        } catch (_) {
          continue;
        }
      }
    }
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } catch (e) {
      debugPrint('signInAnonymously error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }

  bool get isSignedIn => currentUser != null;

  String getDisplayName() {
    if (currentUser == null) return 'Guest';
    final shortId = currentUser!.uid.substring(0, 6);
    return 'Player_$shortId';
  }
}
