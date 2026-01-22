import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitgate_shared/fitgate_shared.dart';

/// Firestore service for managing members, lockers, and activity logs
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ MEMBERS ============

  /// Get all members
  Future<List<Member>> getMembers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('members')
          .orderBy('registeredAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Member(
          id: doc.id,
          name: data['name'] ?? '',
          cardId: data['cardId'] ?? '',
          status: data['status'] ?? 'active',
          membershipValidUntil: (data['membershipValidUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
          registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      // Fallback: get members without ordering if registeredAt index doesn't exist
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('members')
            .get();

        List<Member> members = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return Member(
            id: doc.id,
            name: data['name'] ?? '',
            cardId: data['cardId'] ?? '',
            status: data['status'] ?? 'active',
            membershipValidUntil: (data['membershipValidUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
            registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();

        // Sort by registeredAt in Dart
        members.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        return members;
      } catch (fallbackError) {
        throw Exception('Greška pri učitavanju članova: $e');
      }
    }
  }

  /// Get members as stream for realtime updates
  Stream<List<Member>> getMembersStream() {
    return _firestore.collection('members').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        return Member(
          id: doc.id,
          name: data['name'] ?? '',
          cardId: data['cardId'] ?? '',
          status: data['status'] ?? 'active',
          membershipValidUntil: (data['membershipValidUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
          registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList()..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    });
  }

  /// Get single member by ID
  Future<Member?> getMember(String memberId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('members')
          .doc(memberId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Member(
        id: doc.id,
        name: data['name'] ?? '',
        cardId: data['cardId'] ?? '',
        status: data['status'] ?? 'active',
        membershipValidUntil: (data['membershipValidUntil'] as Timestamp?)?.toDate() ?? DateTime.now(), registeredAt: (data['registeredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      throw Exception('Greška pri učitavanju člana: $e');
    }
  }

  /// Get all member data including additional fields
  Future<Map<String, dynamic>?> getMemberData(String memberId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('members')
          .doc(memberId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data;
    } catch (e) {
      throw Exception('Greška pri učitavanju podataka člana: $e');
    }
  }

  /// Create new member
  Future<String> createMember(Member member) async {
    try {
      DocumentReference docRef = await _firestore.collection('members').add({
        'name': member.name,
        'email': '', // Add email field if needed
        'phoneNumber': null,
        'cardId': member.cardId,
        'status': member.status,
        'assignedLockerId': null,
        'membershipValidUntil': Timestamp.fromDate(member.membershipValidUntil),
        'registeredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastAccessTime': null,
        'notes': null,
      });

      return docRef.id;
    } catch (e) {
      throw Exception('Greška pri kreiranju člana: $e');
    }
  }

  /// Update existing member
  Future<void> updateMember(String memberId, Member member) async {
    try {
      await _firestore.collection('members').doc(memberId).update({
        'name': member.name,
        'cardId': member.cardId,
        'status': member.status,
        'membershipValidUntil': Timestamp.fromDate(member.membershipValidUntil),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri ažuriranju člana: $e');
    }
  }

  /// Delete member
  Future<void> deleteMember(String memberId) async {
    try {
      await _firestore.collection('members').doc(memberId).delete();
    } catch (e) {
      throw Exception('Greška pri brisanju člana: $e');
    }
  }

  // ============ LOCKERS ============

  /// Get all lockers
  Future<List<Locker>> getLockers() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('lockers')
          .orderBy('number')
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Locker(
          id: doc.id,
          number: data['number'] ?? '',
          sector: data['sector'] ?? '',
          status: data['status'] ?? 'free',
          assignedTo: data['currentMember'],
          lastAccessTime: (data['lastAccessTime'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju ormara: $e');
    }
  }

  /// Get single locker by ID
  Future<Locker?> getLocker(String lockerId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('lockers')
          .doc(lockerId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Locker(
        id: doc.id,
        number: data['number'] ?? '',
        sector: data['sector'] ?? '',
        status: data['status'] ?? 'free',
        assignedTo: data['currentMember'],
        lastAccessTime: (data['lastAccessTime'] as Timestamp?)?.toDate(),
      );
    } catch (e) {
      throw Exception('Greška pri učitavanju ormara: $e');
    }
  }

  /// Update locker
  Future<void> updateLocker(String lockerId, Locker locker) async {
    try {
      await _firestore.collection('lockers').doc(lockerId).update({
        'number': locker.number,
        'sector': locker.sector,
        'status': locker.status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Greška pri ažuriranju ormara: $e');
    }
  }

  /// Assign available locker to member by card ID
  Future<Map<String, dynamic>> assignLockerToMember(String cardId, String staffId) async {
    try {
      // Find member by card ID
      QuerySnapshot memberSnapshot = await _firestore
          .collection('members')
          .where('cardId', isEqualTo: cardId)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isEmpty) {
        throw Exception('Član sa tom karticom nije pronađen');
      }

      final memberDoc = memberSnapshot.docs.first;
      String memberId = memberDoc.id;
      Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;

      // Find available lockers
      QuerySnapshot availableLockers = await _firestore
          .collection('lockers')
          .where('status', isEqualTo: 'free')
          .limit(100)
          .get();

      if (availableLockers.docs.isEmpty) {
        throw Exception('Nema dostupnih ormara');
      }

      // Pick random available locker
      final randomIndex = (DateTime.now().millisecondsSinceEpoch % availableLockers.docs.length).toInt();
      final selectedLocker = availableLockers.docs[randomIndex];
      String lockerId = selectedLocker.id;
      Map<String, dynamic> lockerData = selectedLocker.data() as Map<String, dynamic>;
      String lockerNumber = lockerData['number'] ?? 'N/A';
      String lockerSector = lockerData['sector'] ?? 'N/A';

      // Update locker
      await _firestore.collection('lockers').doc(lockerId).update({
        'status': 'occupied',
        'assignedMemberId': memberId,
        'currentMember': memberData['name'] ?? 'Unknown',
        'lastAccessTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update member with locker details
      await _firestore.collection('members').doc(memberId).update({
        'assignedLockerId': lockerId,
        'assignedLockerSector': lockerSector,
        'assignedLockerNumber': lockerNumber,
        'lastAccessTime': FieldValue.serverTimestamp(),
        'cardAssigned': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _logActivity(
        action: 'assign_locker',
        memberId: memberId,
        memberName: memberData['name'],
        lockerId: lockerId,
        lockerNumber: lockerNumber,
        lockerSector: lockerSector,
        staffId: staffId,
        description: 'Ormar $lockerSector-$lockerNumber asigniran članu ${memberData['name']}',
        success: true,
      );

      return {
        'success': true,
        'memberId': memberId,
        'memberName': memberData['name'],
        'lockerId': lockerId,
        'lockerNumber': lockerNumber,
      };
    } catch (e) {
      throw Exception('Greška pri asignaciji ormara: $e');
    }
  }

  /// Assign specific locker to member by member ID and locker ID
  Future<Map<String, dynamic>> assignSpecificLockerToMember({
    required String memberId,
    required String lockerId,
    required String staffId,
  }) async {
    try {
      // Get member data
      DocumentSnapshot memberDoc = await _firestore.collection('members').doc(memberId).get();
      if (!memberDoc.exists) {
        throw Exception('Član nije pronađen');
      }
      
      Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;

      // Get locker data
      DocumentSnapshot lockerDoc = await _firestore.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        throw Exception('Ormar nije pronađen');
      }
      
      Map<String, dynamic> lockerData = lockerDoc.data() as Map<String, dynamic>;
      String lockerNumber = lockerData['number'] ?? 'N/A';
      String lockerSector = lockerData['sector'] ?? 'N/A';

      // Check if locker is available
      if (lockerData['status'] != 'free') {
        throw Exception('Ormar nije dostupan (status: ${lockerData['status']})');
      }

      // Check if member already has a locker
      if (memberData['assignedLockerId'] != null) {
        throw Exception('Član već ima asigniran ormar ${memberData['assignedLockerNumber']}');
      }

      // Update locker
      await _firestore.collection('lockers').doc(lockerId).update({
        'status': 'occupied',
        'assignedMemberId': memberId,
        'currentMember': memberData['name'] ?? 'Unknown',
        'lastAccessTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update member with locker details
      await _firestore.collection('members').doc(memberId).update({
        'assignedLockerId': lockerId,
        'assignedLockerSector': lockerSector,
        'assignedLockerNumber': lockerNumber,
        'lastAccessTime': FieldValue.serverTimestamp(),
        'cardAssigned': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await logActivity(
        action: 'assign_locker',
        memberId: memberId,
        memberName: memberData['name'],
        lockerId: lockerId,
        lockerNumber: lockerNumber,
        lockerSector: lockerSector,
        staffId: staffId,
        description: 'Ormar $lockerSector-$lockerNumber asigniran članu ${memberData['name']}',
        success: true,
      );

      return {
        'success': true,
        'memberId': memberId,
        'memberName': memberData['name'],
        'lockerId': lockerId,
        'lockerNumber': lockerNumber,
        'lockerSector': lockerSector,
      };
    } catch (e) {
      throw Exception('Greška pri asignaciji ormara: $e');
    }
  }

  /// Assign specific locker to member by RFID card ID
  Future<Map<String, dynamic>> assignSpecificLockerByRFID({
    required String cardId,
    required String lockerId,
    required String staffId,
  }) async {
    try {
      // Find member by card ID
      QuerySnapshot memberSnapshot = await _firestore
          .collection('members')
          .where('cardId', isEqualTo: cardId)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isEmpty) {
        throw Exception('Član sa tom karticom nije pronađen');
      }

      final memberDoc = memberSnapshot.docs.first;
      String memberId = memberDoc.id;
      Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;

      // Get locker data
      DocumentSnapshot lockerDoc = await _firestore.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        throw Exception('Ormar nije pronađen');
      }
      
      Map<String, dynamic> lockerData = lockerDoc.data() as Map<String, dynamic>;
      String lockerNumber = lockerData['number'] ?? 'N/A';
      String lockerSector = lockerData['sector'] ?? 'N/A';

      // Check if locker is available
      if (lockerData['status'] != 'free') {
        throw Exception('Ormar nije dostupan (status: ${lockerData['status']})');
      }

      // Check if member already has a locker
      if (memberData['assignedLockerId'] != null) {
        throw Exception('Član ${memberData['name']} već ima asigniran ormar ${memberData['assignedLockerNumber']}');
      }

      // Update locker
      await _firestore.collection('lockers').doc(lockerId).update({
        'status': 'occupied',
        'assignedMemberId': memberId,
        'currentMember': memberData['name'] ?? 'Unknown',
        'lastAccessTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update member with locker details
      await _firestore.collection('members').doc(memberId).update({
        'assignedLockerId': lockerId,
        'assignedLockerSector': lockerSector,
        'assignedLockerNumber': lockerNumber,
        'lastAccessTime': FieldValue.serverTimestamp(),
        'cardAssigned': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await logActivity(
        action: 'assign_locker',
        memberId: memberId,
        memberName: memberData['name'],
        lockerId: lockerId,
        lockerNumber: lockerNumber,
        lockerSector: lockerSector,
        staffId: staffId,
        description: 'Ormar $lockerSector-$lockerNumber asigniran članu ${memberData['name']}',
        success: true,
      );

      return {
        'success': true,
        'memberId': memberId,
        'memberName': memberData['name'],
        'lockerId': lockerId,
        'lockerNumber': lockerNumber,
        'lockerSector': lockerSector,
      };
    } catch (e) {
      throw Exception('Greška pri asignaciji ormara: $e');
    }
  }

  /// Force release locker (staff action)
  Future<void> forceReleaseLocker(
    String lockerId,
    String staffId,
    String reason,
  ) async {
    try {
      // Get locker data first
      DocumentSnapshot lockerDoc = await _firestore
          .collection('lockers')
          .doc(lockerId)
          .get();

      Map<String, dynamic> lockerData = lockerDoc.data() as Map<String, dynamic>;
      String? memberId = lockerData['assignedMemberId'];

      // Update locker status
      await _firestore.collection('lockers').doc(lockerId).update({
        'status': 'free',
        'assignedMemberId': null,
        'currentMember': null,
        'lastAccessTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update member if assigned
      if (memberId != null) {
        await _firestore.collection('members').doc(memberId).update({
          'assignedLockerId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Log activity
      await _logActivity(
        action: 'force_release',
        lockerId: lockerId,
        memberId: memberId,
        staffId: staffId,
        description: 'Prisilno oslobađanje ormara: $reason',
        success: true,
      );
    } catch (e) {
      throw Exception('Greška pri oslobađanju ormara: $e');
    }
  }

  /// Mark locker as out of service
  Future<void> markLockerOutOfService(
    String lockerId,
    String staffId,
    String reason,
    DateTime? estimatedRepairDate,
  ) async {
    try {
      await _firestore.collection('lockers').doc(lockerId).update({
        'status': 'out_of_service',
        'outOfServiceSince': FieldValue.serverTimestamp(),
        'outOfServiceReason': reason,
        'estimatedRepairDate': estimatedRepairDate != null
            ? Timestamp.fromDate(estimatedRepairDate)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log activity
      await _logActivity(
        action: 'mark_out_of_service',
        lockerId: lockerId,
        staffId: staffId,
        description: 'Označeno kao neispravno: $reason',
        success: true,
      );
    } catch (e) {
      throw Exception('Greška pri označavanju ormara: $e');
    }
  }

  // ============ ACTIVITY LOGS ============

  /// Get recent activity logs
  Future<List<Map<String, dynamic>>> getActivityLogs({int limit = 50}) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('activityLogs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'action': data['action'] ?? '',
          'memberName': data['memberName'] ?? '',
          'lockerId': data['lockerNumber'] ?? data['lockerId'] ?? '',
          'staffName': data['staffName'] ?? '',
          'description': data['description'] ?? '',
          'success': data['success'] ?? true,
        };
      }).toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju aktivnosti: $e');
    }
  }

  /// Log an activity (public method for external use)
  Future<void> logActivity({
    required String action,
    String? memberId,
    String? memberName,
    String? lockerId,
    String? lockerNumber,
    String? lockerSector,
    String? staffId,
    String? staffName,
    required String description,
    required bool success,
    String? errorMessage,
  }) async {
    await _logActivity(
      action: action,
      memberId: memberId,
      memberName: memberName,
      lockerId: lockerId,
      lockerNumber: lockerNumber,
      lockerSector: lockerSector,
      staffId: staffId,
      staffName: staffName,
      description: description,
      success: success,
      errorMessage: errorMessage,
    );
  }

  /// Log an activity (internal helper)
  Future<void> _logActivity({
    required String action,
    String? memberId,
    String? memberName,
    String? lockerId,
    String? lockerNumber,
    String? lockerSector,
    String? staffId,
    String? staffName,
    required String description,
    required bool success,
    String? errorMessage,
  }) async {
    try {
      await _firestore.collection('activityLogs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'action': action,
        'memberId': memberId,
        'memberName': memberName,
        'lockerId': lockerId,
        'lockerSector': lockerSector,
        'lockerNumber': lockerNumber,
        'staffId': staffId,
        'staffName': staffName,
        'description': description,
        'success': success,
        'errorMessage': errorMessage,
        'status': 'completed',
      });
    } catch (e) {
      // Silently fail - don't throw on logging errors
    }
  }

  // ============ DASHBOARD STATS ============

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Get active members (filter by status only, then validate membership in code)
      QuerySnapshot activeMembersSnapshot = await _firestore
          .collection('members')
          .where('status', isEqualTo: 'active')
          .get();

      // Count members with valid membership
      int validMembers = 0;
      for (var doc in activeMembersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        DateTime? validUntil = (data['membershipValidUntil'] as Timestamp?)?.toDate();
        if (validUntil != null && validUntil.isAfter(DateTime.now())) {
          validMembers++;
        }
      }

      // Get lockers by status
      QuerySnapshot lockersSnapshot = await _firestore
          .collection('lockers')
          .get();

      int freeLockers = 0;
      int occupiedLockers = 0;
      int outOfServiceLockers = 0;

      for (var doc in lockersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'free';
        
        if (status == 'free') {
          freeLockers++;
        } else if (status == 'occupied') {
          occupiedLockers++;
        } else if (status == 'out_of_service') {
          outOfServiceLockers++;
        }
      }

      return {
        'activeMembersCount': validMembers,
        'activeSessionsCount': occupiedLockers,
        'freeLockers': freeLockers,
        'occupiedLockers': occupiedLockers,
        'outOfServiceLockers': outOfServiceLockers,
        'totalLockers': lockersSnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Greška pri učitavanju statistike: $e');
    }
  }

  // ============ LOCKER ACCESS VERIFICATION ============

  /// Verify if RFID card is authorized for locker access
  /// Returns member info and locker info if authorized
  Future<Map<String, dynamic>?> verifyRFIDAccess({
    required String cardId,
    required String lockerId,
  }) async {
    try {
      // Find member by card ID
      QuerySnapshot memberSnapshot = await _firestore
          .collection('members')
          .where('cardId', isEqualTo: cardId)
          .limit(1)
          .get();

      if (memberSnapshot.docs.isEmpty) {
        return null; // Card not found
      }

      final memberDoc = memberSnapshot.docs.first;
      String memberId = memberDoc.id;
      Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;

      // Check if member is active
      if (memberData['status'] != 'active') {
        return null; // Member not active
      }

      // Check membership validity
      DateTime membershipUntil = (memberData['membershipValidUntil'] as Timestamp?)?.toDate() ?? DateTime.now();
      if (membershipUntil.isBefore(DateTime.now())) {
        return null; // Membership expired
      }

      // Get locker data
      DocumentSnapshot lockerDoc = await _firestore.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        return null;
      }

      Map<String, dynamic> lockerData = lockerDoc.data() as Map<String, dynamic>;

      // Check if locker is occupied by this member
      if (lockerData['assignedMemberId'] != memberId) {
        return null; // Locker not assigned to this member
      }

      // Check if locker is in service
      if (lockerData['status'] != 'occupied') {
        return null; // Locker not available
      }

      // Authorized! Create locker session
      await _createLockerSession(
        lockerId: lockerId,
        memberId: memberId,
        cardId: cardId,
      );

      return {
        'authorized': true,
        'memberId': memberId,
        'memberName': memberData['name'],
        'lockerId': lockerId,
        'lockerNumber': lockerData['number'],
        'lockerSector': lockerData['sector'],
      };
    } catch (e) {
      throw Exception('Greška pri verifikaciji pristupa: $e');
    }
  }

  /// Create a locker session record
  Future<void> _createLockerSession({
    required String lockerId,
    required String memberId,
    required String cardId,
  }) async {
    try {
      await _firestore.collection('lockerSessions').add({
        'lockerId': lockerId,
        'assignedUserId': memberId,
        'authorizedUid': cardId,
        'createdAt': FieldValue.serverTimestamp(),
        'accessType': 'rfid',
        'status': 'active',
      });
    } catch (e) {
      // Log error but don't throw - access should still be granted
      print('Greška pri kreiranju locker sesije: $e');
    }
  }

  /// Close a locker session (when member releases the locker)
  Future<void> closeLockerSession(String lockerId, String memberId) async {
    try {
      // Find active session for this locker and member
      QuerySnapshot sessionSnapshot = await _firestore
          .collection('lockerSessions')
          .where('lockerId', isEqualTo: lockerId)
          .where('assignedUserId', isEqualTo: memberId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (sessionSnapshot.docs.isNotEmpty) {
        await _firestore
            .collection('lockerSessions')
            .doc(sessionSnapshot.docs.first.id)
            .update({
          'closedAt': FieldValue.serverTimestamp(),
          'status': 'closed',
        });
      }
    } catch (e) {
      print('Greška pri zatvaranju sesije: $e');
    }
  }

  /// Log failed access attempt
  Future<void> logFailedAccessAttempt({
    required String lockerId,
    required String cardId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('accessAttempts').add({
        'lockerId': lockerId,
        'cardId': cardId,
        'timestamp': FieldValue.serverTimestamp(),
        'success': false,
        'reason': reason,
      });
    } catch (e) {
      print('Greška pri logiranju neuspješnog pokušaja: $e');
    }
  }

  /// Get active locker sessions for a member
  Future<List<Map<String, dynamic>>> getActiveMemberSessions(String memberId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('lockerSessions')
          .where('assignedUserId', isEqualTo: memberId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => {
                'sessionId': doc.id,
                ...(doc.data() as Map<String, dynamic>)
              })
          .toList();
    } catch (e) {
      throw Exception('Greška pri učitavanju sesija: $e');
    }
  }
}
