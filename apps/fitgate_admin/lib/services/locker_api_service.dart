import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// REST API service for NodeMCU locker hardware
/// Provides endpoints for RFID verification and locker control
class LockerAPIService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verify RFID card and grant/deny access to locker
  /// Expected request body:
  /// {
  ///   "cardId": "1234567890",
  ///   "lockerId": "locker_doc_id"
  /// }
  /// Returns:
  /// {
  ///   "authorized": true/false,
  ///   "memberName": "John Doe",
  ///   "lockerId": "...",
  ///   "lockerNumber": "A06",
  ///   "reason": "Card not authorized" (if not authorized)
  /// }
  Future<Map<String, dynamic>> verifyAndAuthorize({
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
        await _logFailedAttempt(lockerId, cardId, 'Card not found');
        return {
          'authorized': false,
          'reason': 'Kartisa nije pronađena',
          'code': 'CARD_NOT_FOUND',
        };
      }

      final memberDoc = memberSnapshot.docs.first;
      String memberId = memberDoc.id;
      Map<String, dynamic> memberData = memberDoc.data() as Map<String, dynamic>;

      // Check if member is active
      if (memberData['status'] != 'active') {
        await _logFailedAttempt(lockerId, cardId, 'Member not active');
        return {
          'authorized': false,
          'reason': 'Član nije aktivan',
          'code': 'MEMBER_INACTIVE',
        };
      }

      // Check membership validity
      DateTime membershipUntil = (memberData['membershipValidUntil'] as Timestamp?)?.toDate() ?? DateTime.now();
      if (membershipUntil.isBefore(DateTime.now())) {
        await _logFailedAttempt(lockerId, cardId, 'Membership expired');
        return {
          'authorized': false,
          'reason': 'Članstvo je isteklo',
          'code': 'MEMBERSHIP_EXPIRED',
        };
      }

      // Get locker data
      DocumentSnapshot lockerDoc = await _firestore.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        await _logFailedAttempt(lockerId, cardId, 'Locker not found');
        return {
          'authorized': false,
          'reason': 'Ormar nije pronađen',
          'code': 'LOCKER_NOT_FOUND',
        };
      }

      Map<String, dynamic> lockerData = lockerDoc.data() as Map<String, dynamic>;

      // Check if locker is assigned to this member
      if (lockerData['assignedMemberId'] != memberId) {
        await _logFailedAttempt(
          lockerId,
          cardId,
          'Locker not assigned to member',
        );
        return {
          'authorized': false,
          'reason': 'Ormar nije asigniran ovom članu',
          'code': 'LOCKER_NOT_ASSIGNED',
        };
      }

      // Check if locker is in service
      if (lockerData['status'] != 'occupied') {
        await _logFailedAttempt(lockerId, cardId, 'Locker not available');
        return {
          'authorized': false,
          'reason': 'Ormar nije dostupan',
          'code': 'LOCKER_UNAVAILABLE',
        };
      }

      // AUTHORIZED! Create session and return success
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
        'message': 'Pristup dozvoljen',
        'code': 'ACCESS_GRANTED',
      };
    } catch (e) {
      return {
        'authorized': false,
        'reason': 'Greška pri verifikaciji: ${e.toString()}',
        'code': 'ERROR',
      };
    }
  }

  /// Get locker info by ID
  Future<Map<String, dynamic>?> getLockerInfo(String lockerId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('lockers').doc(lockerId).get();
      
      if (!doc.exists) {
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      return {
        'lockerId': lockerId,
        'number': data['number'],
        'sector': data['sector'],
        'status': data['status'],
        'assignedMemberId': data['assignedMemberId'],
        'currentMember': data['currentMember'],
      };
    } catch (e) {
      throw Exception('Greška pri učitavanju info o ormaru: $e');
    }
  }

  /// Get member info by card ID
  Future<Map<String, dynamic>?> getMemberByCard(String cardId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('members')
          .where('cardId', isEqualTo: cardId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      Map<String, dynamic> data = snapshot.docs.first.data() as Map<String, dynamic>;
      
      return {
        'memberId': snapshot.docs.first.id,
        'name': data['name'],
        'cardId': data['cardId'],
        'status': data['status'],
        'assignedLockerId': data['assignedLockerId'],
        'assignedLockerNumber': data['assignedLockerNumber'],
      };
    } catch (e) {
      throw Exception('Greška pri učitavanju info o članu: $e');
    }
  }

  /// Create locker access session
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
        'nodeId': null, // Can be set by NodeMCU
      });
    } catch (e) {
      debugPrint('Greška pri kreiranju sesije: $e');
    }
  }

  /// Log failed access attempt
  Future<void> _logFailedAttempt(
    String lockerId,
    String cardId,
    String reason,
  ) async {
    try {
      await _firestore.collection('accessAttempts').add({
        'lockerId': lockerId,
        'cardId': cardId,
        'timestamp': FieldValue.serverTimestamp(),
        'success': false,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Greška pri logiranju pokušaja: $e');
    }
  }

  /// Close an active locker session (when member releases)
  Future<void> closeSession({
    required String lockerId,
    required String memberId,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('lockerSessions')
          .where('lockerId', isEqualTo: lockerId)
          .where('assignedUserId', isEqualTo: memberId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await _firestore
            .collection('lockerSessions')
            .doc(snapshot.docs.first.id)
            .update({
          'closedAt': FieldValue.serverTimestamp(),
          'status': 'closed',
        });
      }
    } catch (e) {
      debugPrint('Greška pri zatvaranju sesije: $e');
    }
  }

  /// Get active sessions for locker
  Future<List<Map<String, dynamic>>> getActiveSessionsForLocker(String lockerId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('lockerSessions')
          .where('lockerId', isEqualTo: lockerId)
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

  /// Health check endpoint for NodeMCU
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      // Try a simple read to verify connection
      await _firestore.collection('lockers').limit(1).get();
      
      return {
        'status': 'ok',
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Firebase je dostupan',
      };
    } catch (e) {
      return {
        'status': 'error',
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Firebase nije dostupan: $e',
      };
    }
  }
}
