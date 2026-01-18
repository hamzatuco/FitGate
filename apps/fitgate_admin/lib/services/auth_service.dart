import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service using Firebase Auth
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Login with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Sign in with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Fetch user data from Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
          print(userDoc.data());
      if (!userDoc.exists) {
        await logout();
        throw Exception('Korisnik ne postoji u bazi');
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if user is admin or staff
      String role = userData['role'] ?? '';
      if (role != 'admin' && role != 'staff') {
        await logout();
        throw Exception('Nemate dozvolu za pristup admin panelu');
      }

      // Check if user is active
      if (userData['isActive'] == false) {
        await logout();
        throw Exception('Vaš nalog je deaktiviran');
      }

      // Update last login timestamp
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Save login state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userCredential.user!.uid);

      return {
        'success': true,
        'user': userData,
        'uid': userCredential.user!.uid,
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Greška pri prijavi';
      if (e.code == 'user-not-found') {
        message = 'Korisnik ne postoji';
      } else if (e.code == 'wrong-password') {
        message = 'Pogrešna lozinka';
      } else if (e.code == 'invalid-email') {
        message = 'Nevažeća email adresa';
      } else if (e.code == 'user-disabled') {
        message = 'Korisnički nalog je onemogućen';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Get stored user ID
  Future<String?> getStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Validate current session
  Future<bool> validateSession() async {
    return currentUser != null && await isLoggedIn();
  }

  // Get current user data from Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    if (currentUser == null) return null;

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
}
