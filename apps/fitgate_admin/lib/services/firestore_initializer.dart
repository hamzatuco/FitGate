import 'package:cloud_firestore/cloud_firestore.dart';

/// Initialize Firestore collections with sample data
class FirestoreInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize all collections
  Future<void> initializeCollections() async {
    try {
      print('🔧 Inicijalizujem Firestore kolekcije...');
      
      await createLockers();
      await createActivityLogs();
      
      print('✅ Sve kolekcije su uspešno kreirane!');
    } catch (e) {
      print('❌ Greška pri inicijalizaciji: $e');
      rethrow;
    }
  }

  /// Create lockers collection with sample data
  Future<void> createLockers() async {
    print('\n📦 Kreiram ormare...');
    
    final sectors = ['A', 'B', 'C', 'D'];
    int counter = 0;

    // Batch write for efficiency
    WriteBatch batch = _firestore.batch();

    for (String sector in sectors) {
      for (int i = 1; i <= 10; i++) {
        counter++;
        final lockerNumber = '$sector${i.toString().padLeft(2, '0')}';
        
        final docRef = _firestore.collection('lockers').doc();
        
        batch.set(docRef, {
          'number': lockerNumber,
          'sector': sector,
          'status': 'free', // free, occupied, out_of_service
          'assignedMemberId': null,
          'currentMember': null,
          'lastAccessTime': null,
          'outOfServiceSince': null,
          'outOfServiceReason': null,
          'estimatedRepairDate': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Commit batch every 100 writes
        if (counter % 100 == 0) {
          await batch.commit();
          batch = _firestore.batch();
          print('  ✓ Napravljeno $counter ormara...');
        }
      }
    }

    // Commit remaining writes
    await batch.commit();
    print('  ✓ Ukupno napravljeno: $counter ormara');
  }

  /// Create activity logs collection (initially empty)
  Future<void> createActivityLogs() async {
    print('\n📋 Kreiram aktivnost log...');

    // Create a sample activity log entry to initialize the collection
    await _firestore.collection('activityLogs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'action': 'system_init',
      'memberId': null,
      'lockerId': null,
      'staffId': 'system',
      'memberName': null,
      'description': 'Sistem je inicijalizovan - sve kolekcije su kreirane',
      'success': true,
      'errorMessage': null,
    });

    print('  ✓ ActivityLogs kolekcija je kreirana');
  }
}
