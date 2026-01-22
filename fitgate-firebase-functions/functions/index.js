const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

admin.initializeApp();
const db = admin.firestore();

// Use Europe region for all functions
const europeFunction = functions.region('europe-west1');

// Verify RFID card and grant/deny locker access
exports.verifyLockerAccess = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
      res.status(200).send();
      return;
    }

    try {
      const { cardId, lockerId } = req.body;

      if (!cardId || !lockerId) {
        return res.status(400).json({
          authorized: false,
          reason: 'Missing cardId or lockerId',
          code: 'INVALID_REQUEST'
        });
      }

      // Find member by card ID
      const memberSnap = await db.collection('members')
        .where('cardId', '==', cardId)
        .limit(1)
        .get();

      if (memberSnap.empty) {
        // Log failed attempt
        await db.collection('accessAttempts').add({
          lockerId,
          cardId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          success: false,
          reason: 'Card not found'
        });
        // Upisi obavijest korisniku (ako postoji)
        const lockerDoc = await db.collection('lockers').doc(lockerId).get();
        const lockerNum = lockerDoc.exists ? lockerDoc.data().number : '';
        // 1. Pokušaj upisa notifikacije članu s tom karticom
        await db.collection('members').where('cardId', '==', cardId).get().then(snap => {
          snap.forEach(doc => {
            db.collection('members').doc(doc.id).collection('notifications').add({
              message: `Pokušaj otvaranja ormarića ${lockerNum ? lockerNum : lockerId} nije uspio (kartica nije prepoznata).`,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              type: 'fail',
            });
          });
        });
        // 2. Ako ormar ima dodijeljenog člana, upiši i njemu notifikaciju
        if (lockerDoc.exists && lockerDoc.data().assignedMemberId) {
          const ownerId = lockerDoc.data().assignedMemberId;
          await db.collection('members').doc(ownerId).collection('notifications').add({
            message: `Pokušaj otvaranja vašeg ormarića ${lockerNum ? lockerNum : lockerId} nije uspio (neprepoznata kartica).`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            type: 'fail',
          });
        }
        return res.status(401).json({
          authorized: false,
          reason: 'Kartisa nije pronađena',
          code: 'CARD_NOT_FOUND'
        });
      }

      const memberDoc = memberSnap.docs[0];
      const memberId = memberDoc.id;
      const memberData = memberDoc.data();

      // Check member status
      if (memberData.status !== 'active') {
        await db.collection('accessAttempts').add({
          lockerId,
          cardId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          success: false,
          reason: 'Member not active'
        });
        await db.collection('members').doc(memberId).collection('notifications').add({
          message: `Pokušaj otvaranja ormarića ${lockerId} nije uspio (član nije aktivan).`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: 'fail',
        });
        return res.status(401).json({
          authorized: false,
          reason: 'Član nije aktivan',
          code: 'MEMBER_INACTIVE'
        });
      }

      // Check membership validity
      const membershipUntil = memberData.membershipValidUntil?.toDate() || new Date();
      if (membershipUntil < new Date()) {
        await db.collection('accessAttempts').add({
          lockerId,
          cardId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          success: false,
          reason: 'Membership expired'
        });
        await db.collection('members').doc(memberId).collection('notifications').add({
          message: `Pokušaj otvaranja ormarića ${lockerId} nije uspio (članstvo isteklo).`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: 'fail',
        });
        return res.status(401).json({
          authorized: false,
          reason: 'Članstvo je isteklo',
          code: 'MEMBERSHIP_EXPIRED'
        });
      }

      // Get locker
      const lockerDoc = await db.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        return res.status(404).json({
          authorized: false,
          reason: 'Ormar nije pronađen',
          code: 'LOCKER_NOT_FOUND'
        });
      }

      const lockerData = lockerDoc.data();

      // Check if locker is assigned to this member
      if (lockerData.assignedMemberId !== memberId) {
        await db.collection('accessAttempts').add({
          lockerId,
          cardId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          success: false,
          reason: 'Locker not assigned to member'
        });
        await db.collection('members').doc(memberId).collection('notifications').add({
          message: `Pokušaj otvaranja ormarića ${lockerData.number || lockerId} nije uspio (ormar nije dodijeljen ovom članu).`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: 'fail',
        });
        // Upisi notifikaciju i vlasniku ormarića
        if (lockerData.assignedMemberId) {
          await db.collection('members').doc(lockerData.assignedMemberId).collection('notifications').add({
            message: `Pokušaj otvaranja vašeg ormarića ${lockerData.number || lockerId} nije uspio (pokušaj od strane drugog člana).`,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            type: 'fail',
          });
        }
        return res.status(401).json({
          authorized: false,
          reason: 'Ormar nije asigniran ovom članu',
          code: 'LOCKER_NOT_ASSIGNED'
        });
      }

      // Check locker status
      if (lockerData.status !== 'occupied') {
        await db.collection('members').doc(memberId).collection('notifications').add({
          message: `Pokušaj otvaranja ormarića ${lockerData.number || lockerId} nije uspio (ormar nije dostupan).`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          type: 'fail',
        });
        return res.status(401).json({
          authorized: false,
          reason: 'Ormar nije dostupan',
          code: 'LOCKER_UNAVAILABLE'
        });
      }

      // ACCESS GRANTED!
      // Prvo obriši sve stare sesije za taj ormar i člana
      const oldSessions = await db.collection('lockerSessions')
        .where('lockerId', '==', lockerId)
        .where('assignedUserId', '==', memberId)
        .get();
      const batch = db.batch();
      oldSessions.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      // Dodaj samo jednu aktivnu sesiju
      await db.collection('lockerSessions').add({
        lockerId,
        assignedUserId: memberId,
        authorizedUid: cardId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        accessType: 'rfid',
        status: 'active'
      });
      // Log successful access
      await db.collection('accessAttempts').add({
        lockerId,
        cardId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        success: true,
        memberId,
        memberName: memberData.name
      });
      // Upisi obavijest korisniku
      await db.collection('members').doc(memberId).collection('notifications').add({
        message: `Ormarić ${lockerData.number || lockerId} je uspješno otvoren.`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'success',
      });
      return res.status(200).json({
        authorized: true,
        memberId,
        memberName: memberData.name,
        lockerId,
        lockerNumber: lockerData.number,
        lockerSector: lockerData.sector,
        message: 'Pristup dozvoljen',
        code: 'ACCESS_GRANTED'
      });

    } catch (error) {
      console.error('Error:', error);
      return res.status(500).json({
        authorized: false,
        reason: 'Greška pri verifikaciji: ' + error.message,
        code: 'ERROR'
      });
    }
  });
});

// Health check endpoint
exports.healthCheck = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      // Try a simple read to verify connection
      await db.collection('lockers').limit(1).get();

      return res.status(200).json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        message: 'Firebase je dostupan'
      });
    } catch (error) {
      return res.status(500).json({
        status: 'error',
        timestamp: new Date().toISOString(),
        message: 'Firebase nije dostupan: ' + error.message
      });
    }
  });
});

// Get member by card ID
exports.getMemberByCard = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { cardId } = req.query;

      if (!cardId) {
        return res.status(400).json({
          error: 'Missing cardId parameter'
        });
      }

      const snap = await db.collection('members')
        .where('cardId', '==', cardId)
        .limit(1)
        .get();

      if (snap.empty) {
        return res.status(404).json({
          error: 'Member not found'
        });
      }

      const data = snap.docs[0].data();
      return res.status(200).json({
        memberId: snap.docs[0].id,
        name: data.name,
        cardId: data.cardId,
        status: data.status,
        assignedLockerId: data.assignedLockerId,
        assignedLockerNumber: data.assignedLockerNumber
      });

    } catch (error) {
      return res.status(500).json({
        error: error.message
      });
    }
  });
});

// Get locker info by ID
exports.getLockerInfo = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { lockerId } = req.query;

      if (!lockerId) {
        return res.status(400).json({
          error: 'Missing lockerId parameter'
        });
      }

      const doc = await db.collection('lockers').doc(lockerId).get();

      if (!doc.exists) {
        return res.status(404).json({
          error: 'Locker not found'
        });
      }

      const data = doc.data();
      return res.status(200).json({
        lockerId,
        number: data.number,
        sector: data.sector,
        status: data.status,
        assignedMemberId: data.assignedMemberId,
        currentMember: data.currentMember
      });

    } catch (error) {
      return res.status(500).json({
        error: error.message
      });
    }
  });
});
