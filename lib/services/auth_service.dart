import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Check if user is signed in
  bool get isSignedIn => currentUser != null;

  // Get user display name (or generate default)
  String getDisplayName() {
    if (currentUser == null) return 'Guest';

    // Generate a player name based on UID
    final uid = currentUser!.uid;
    final shortId = uid.substring(0, 6);
    return 'Player_$shortId';
  }
}
