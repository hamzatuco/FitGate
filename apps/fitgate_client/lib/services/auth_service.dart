import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_profile.dart';

/// Authentication service with Firebase integration
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Login with email and password
  Future<AuthUser?> login(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email i lozinka su obavezni');
      }

      if (!email.contains('@')) {
        throw Exception('Nevaljani email format');
      }

      if (password.length < 8) {
        throw Exception('Lozinka mora biti najmanje 8 karaktera');
      }

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return AuthUser(
        uid: userCredential.user!.uid,
        email: userCredential.user!.email ?? '',
        displayName: userCredential.user!.displayName,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Greška pri prijavi';
      if (e.code == 'user-not-found') {
        message = 'Korisnik sa tom email adresom nije pronađen';
      } else if (e.code == 'wrong-password') {
        message = 'Nevaljana lozinka';
      } else if (e.code == 'invalid-email') {
        message = 'Nevaljani email format';
      } else if (e.code == 'user-disabled') {
        message = 'Ovaj račun je onemoguće n';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Register new member
  Future<AuthUser?> register(
    String fullName,
    String email,
    String password,
  ) async {
    try {
      if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Svi polji su obavezni');
      }

      if (!email.contains('@')) {
        throw Exception('Nevaljani email format');
      }

      if (password.length < 8) {
        throw Exception('Lozinka mora biti najmanje 8 karaktera');
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user!;
      await user.updateDisplayName(fullName);
      await user.reload();

      // Create member document in Firestore with auto-generated document ID
      String docId = _firestore.collection('members').doc().id;
      await _firestore.collection('members').doc(docId).set({
        'uid': user.uid,
        'name': fullName,
        'email': email,
        'phoneNumber': null,
        'cardId': null,
        'status': 'active',
        'assignedLockerId': null,
        'assignedLockerSector': null,
        'assignedLockerNumber': null,
        'cardAssigned': false,
        'membershipValidUntil': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAccessTime': null,
        'notificationCount': 0,
        'notes': null,
      });

      return AuthUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: fullName,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Greška pri registraciji';
      if (e.code == 'weak-password') {
        message = 'Lozinka je preslaba';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email je već u upotrebi';
      } else if (e.code == 'invalid-email') {
        message = 'Nevaljani email format';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Send password reset email
  Future<void> forgotPassword(String email) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email je obavezan');
      }

      if (!email.contains('@')) {
        throw Exception('Nevaljani email format');
      }

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      String message = 'Greška pri slanju email-a';
      if (e.code == 'user-not-found') {
        message = 'Korisnik sa tom email adresom nije pronađen';
      } else if (e.code == 'invalid-email') {
        message = 'Nevaljani email format';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Get current user profile
  /// Get current user profile
  Future<MemberProfile?> getCurrentUserProfile() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        throw Exception('Korisnik nije prijavljen');
      }

      // Get member by uid field
      QuerySnapshot query = await _firestore
          .collection('members')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('Profil člana nije pronađen');
      }

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      return MemberProfile(
        id: doc.id,
        fullName: data['name'] ?? currentUser.displayName ?? 'Član',
        email: data['email'] ?? currentUser.email ?? '',
        status: data['status'] ?? 'active',
        membershipValidUntil: (data['membershipValidUntil'] as Timestamp?)?.toDate() ??
            DateTime.now().add(const Duration(days: 30)),
        assignedLockerSector: data['assignedLockerSector'],
        assignedLockerNumber: data['assignedLockerNumber'],
        lastCheckInTime: (data['lastAccessTime'] as Timestamp?)?.toDate(),
        cardAssigned: data['cardAssigned'] ?? false,
        notificationCount: data['notificationCount'] ?? 0,
      );
    } catch (e) {
      throw Exception('Greška pri učitavanju profila: ${e.toString()}');
    }
  }

  /// Stream of current user profile with real-time updates
  Stream<MemberProfile?> getCurrentUserProfileStream() {
    final currentUser = _firebaseAuth.currentUser;
    
    if (currentUser == null) {
      return Stream.value(null);
    }
    
    // Kombinuj member stream sa locker stream-om
    return _firestore
        .collection('members')
        .where('uid', isEqualTo: currentUser.uid)
        .limit(1)
        .snapshots()
        .asyncExpand((memberSnapshot) {
          if (memberSnapshot.docs.isEmpty) {
            return Stream.value(null);
          }

          final memberDoc = memberSnapshot.docs.first;
          final memberData = memberDoc.data();
          
          // Ako member ima assignedLockerSector, koristi te podatke
          if (memberData['assignedLockerSector'] != null && memberData['assignedLockerNumber'] != null) {
            // Provjeravamo da li je kartice dodijeljena
            bool hasCard = memberData['cardId'] != null && (memberData['cardId'] as String).isNotEmpty;
            
            final profile = MemberProfile(
              id: memberDoc.id,
              fullName: memberData['name'] ?? currentUser.displayName ?? 'Član',
              email: memberData['email'] ?? currentUser.email ?? '',
              status: memberData['status'] ?? 'active',
              membershipValidUntil: (memberData['membershipValidUntil'] as Timestamp?)?.toDate() ??
                  DateTime.now().add(const Duration(days: 30)),
              assignedLockerSector: memberData['assignedLockerSector'],
              assignedLockerNumber: memberData['assignedLockerNumber'],
              lastCheckInTime: (memberData['lastAccessTime'] as Timestamp?)?.toDate(),
              cardAssigned: hasCard,
              notificationCount: memberData['notificationCount'] ?? 0,
            );
            
            return Stream.value(profile);
          }

          // Nema locker podataka u member dokumentu, pokuša iz locker kolekcije
          return _firestore
              .collection('lockers')
              .where('assignedMemberId', isEqualTo: memberDoc.id)
              .limit(1)
              .snapshots()
              .map((lockerSnapshot) {
                if (lockerSnapshot.docs.isNotEmpty) {
                  final lockerDoc = lockerSnapshot.docs.first;
                  final lockerData = lockerDoc.data();
                  
                  // Provjeravamo da li je kartice dodijeljena - ako cardId polje nije null
                  bool hasCard = memberData['cardId'] != null && (memberData['cardId'] as String).isNotEmpty;
                  
                  // Kreiraj profile sa locker podacima iz locker dokumenta
                  final profileWithLocker = MemberProfile(
                    id: memberDoc.id,
                    fullName: memberData['name'] ?? currentUser.displayName ?? 'Član',
                    email: memberData['email'] ?? currentUser.email ?? '',
                    status: memberData['status'] ?? 'active',
                    membershipValidUntil: (memberData['membershipValidUntil'] as Timestamp?)?.toDate() ??
                        DateTime.now().add(const Duration(days: 30)),
                    assignedLockerSector: lockerData['sector'],
                    assignedLockerNumber: lockerData['number'],
                    lastCheckInTime: (lockerData['lastAccessTime'] as Timestamp?)?.toDate() ?? 
                        (memberData['lastAccessTime'] as Timestamp?)?.toDate(),
                    cardAssigned: hasCard,
                    notificationCount: memberData['notificationCount'] ?? 0,
                  );
                  
                  return profileWithLocker;
                } else {
                  return _buildMemberProfile(memberDoc.id, memberData, currentUser);
                }
              });
        });
  }

  /// Helper metoda za pravljenje MemberProfile iz member dokumenta
  MemberProfile _buildMemberProfile(String docId, Map<String, dynamic> memberData, User currentUser) {
    // Provjeravamo da li je kartice dodijeljena - ako cardId polje nije null, kartice JE dodijeljena
    bool hasCard = memberData['cardId'] != null && (memberData['cardId'] as String).isNotEmpty;
    
    final profile = MemberProfile(
      id: docId,
      fullName: memberData['name'] ?? currentUser.displayName ?? 'Član',
      email: memberData['email'] ?? currentUser.email ?? '',
      status: memberData['status'] ?? 'active',
      membershipValidUntil: (memberData['membershipValidUntil'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
      assignedLockerSector: memberData['assignedLockerSector'],
      assignedLockerNumber: memberData['assignedLockerNumber'],
      lastCheckInTime: (memberData['lastAccessTime'] as Timestamp?)?.toDate(),
      cardAssigned: hasCard,
      notificationCount: memberData['notificationCount'] ?? 0,
    );
    
    return profile;
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Greška pri odjavi: ${e.toString()}');
    }
  }

  /// Check if user is logged in
  bool get isLoggedIn => _firebaseAuth.currentUser != null;

  /// Get current user
  User? get currentUser => _firebaseAuth.currentUser;
}