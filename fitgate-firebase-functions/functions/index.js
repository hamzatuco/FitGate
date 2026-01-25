/* eslint-disable no-console */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

admin.initializeApp();
const db = admin.firestore();

// Use Europe region for all functions
const europeFunction = functions.region('europe-west1');

const ts = admin.firestore.FieldValue.serverTimestamp();

/**
 * Centralizovan upis attempt-a (APP + RFID) u jednu kolekciju: accessAttempts
 * - status: 'pending' | 'success' | 'fail'
 * - source: 'app' | 'rfid'
 * - action: 'open_request' | 'access_check'
 */
async function createAccessAttempt({
  source,
  action,
  lockerId,
  lockerNumber = null,
  lockerSector = null,
  memberId = null,
  memberName = null,
  cardId = null,
  status,
  reason = null,
  meta = {},
}) {
  const ref = await db.collection('accessAttempts').add({
    source,
    action,
    lockerId,
    lockerNumber,
    lockerSector,
    memberId,
    memberName,
    cardId,
    status,
    reason,
    createdAt: ts,
    resolvedAt: status === 'pending' ? null : ts,
    notified: false,
    ...meta,
  });
  return ref;
}

async function resolveAccessAttempt(attemptId, { status, reason = null, meta = {} }) {
  await db.collection('accessAttempts').doc(attemptId).update({
    status,
    reason,
    resolvedAt: ts,
    ...meta,
  });
}

/**
 * Trigger: kada accessAttempt pređe iz pending -> success/fail,
 * upiši JEDNU notifikaciju u members/{memberId}/notifications i označi notified=true.
 */exports.notifyAccessAttemptResolved = europeFunction.firestore
  .document('accessAttempts/{attemptId}')
  .onWrite(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;

    // deleted doc
    if (!after) return null;

    // već smo poslali notif
    if (after.notified) return null;

    const afterStatus = after.status;

    // zanima nas samo finalno stanje
    if (!['success', 'fail'].includes(afterStatus)) return null;

    // Ako je update, status se mora promijeniti ili je ranije bio pending
    if (before && before.status === afterStatus) {
      // (npr. update nekih drugih polja) -> ne šalji
      return null;
    }

    if (!after.memberId) {
      // nema kome poslati, ali označi da se ne vrti
      await change.after.ref.update({ notified: true });
      return null;
    }

    const lockerLabel =
      after.lockerNumber != null && after.lockerNumber !== ''
        ? `${after.lockerNumber}`
        : (after.lockerId || '');

    const viaApp = after.source === 'app' ? ' putem aplikacije' : '';
    const msg =
      afterStatus === 'success'
        ? `Ormarić ${lockerLabel} je uspješno otvoren${viaApp}.`
        : `Pokušaj otvaranja ormarića ${lockerLabel} nije uspio${after.reason ? ` (${after.reason})` : ''}.`;

    await db.collection('members').doc(after.memberId).collection('notifications').add({
      message: msg,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: afterStatus === 'success' ? 'success' : 'fail',
      source: after.source || 'system',
      attemptId: context.params.attemptId,
      action: after.action || null,
    });

    await change.after.ref.update({ notified: true });
    return null;
  });

/**
 * API endpoint za otvaranje ormarica iz aplikacije
 * - Upisuje accessAttempts: pending (NE upisuje success notifikaciju!)
 * - IoT treba kasnije da rezolvuje attempt (success/fail) update-om istog dokumenta
 */
exports.openLocker = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') return res.status(200).send();

    try {
      const { lockerId, memberId } = req.body;

      if (!lockerId || !memberId) {
        return res.status(400).json({ success: false, message: 'lockerId i memberId su obavezni.' });
      }

      const lockerDoc = await db.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        return res.status(404).json({ success: false, message: 'Ormaric nije pronađen.' });
      }

      const lockerData = lockerDoc.data();
      if (lockerData.assignedMemberId !== memberId) {
        return res.status(403).json({ success: false, message: 'Ormaric nije dodijeljen ovom članu.' });
      }

      // ✅ OVO MCU ČITA
      await db.collection('lockerOpenRequests').add({
        lockerId,
        memberId,
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        source: 'app',
      });

      // ❌ NE upisuj ovdje success/fail notifikacije
      return res.status(200).json({
        success: true,
        message: 'Zahtjev za otvaranje ormarica je poslan.',
      });
    } catch (error) {
      console.error('openLocker error:', error);
      return res.status(500).json({ success: false, message: 'Greška na serveru: ' + error.message });
    }
  });
});

exports.notifyLockerRequestCompleted = europeFunction.firestore
  .document('lockerOpenRequests/{reqId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) return null;
    if (before.status === after.status) return null;

    // samo kad postane completed
    if (after.status !== 'completed') return null;

    // anti-dup (dodaj polje notified u doc)
    if (after.notified === true) return null;

    const memberId = after.memberId;
    const lockerId = after.lockerId;

    if (!memberId || !lockerId) {
      await change.after.ref.update({ notified: true });
      return null;
    }

    const lockerDoc = await db.collection('lockers').doc(lockerId).get();
    const lockerNumber = lockerDoc.exists ? (lockerDoc.data().number || lockerId) : lockerId;

    await db.collection('members').doc(memberId).collection('notifications').add({
      message: `Ormarić ${lockerNumber} je uspješno otvoren putem aplikacije.`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: 'success',
      source: 'app',
      requestId: context.params.reqId,
    });

    await change.after.ref.update({ notified: true });
    return null;
  });

/**
 * Verify RFID card and grant/deny locker access
 * - Upisuje accessAttempts (success/fail) i trigger će napraviti notifikaciju
 */
exports.verifyLockerAccess = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
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
          code: 'INVALID_REQUEST',
        });
      }

      // Get locker first (treba nam za poruke i owner notifikacije)
      const lockerDoc = await db.collection('lockers').doc(lockerId).get();
      if (!lockerDoc.exists) {
        // locker ne postoji -> nema smisla dalje
        await createAccessAttempt({
          source: 'rfid',
          action: 'access_check',
          lockerId,
          cardId,
          status: 'fail',
          reason: 'Ormar nije pronađen',
        });

        return res.status(404).json({
          authorized: false,
          reason: 'Ormar nije pronađen',
          code: 'LOCKER_NOT_FOUND',
        });
      }

      const lockerData = lockerDoc.data();
      const lockerNumber = lockerData.number || lockerId;
      const lockerSector = lockerData.sector || null;

      // Find member by card ID
      const memberSnap = await db.collection('members').where('cardId', '==', cardId).limit(1).get();

      if (memberSnap.empty) {
        // Log failed attempt (unknown card) -> notify locker owner if exists
        const ownerId = lockerData.assignedMemberId || null;

        await createAccessAttempt({
          source: 'rfid',
          action: 'access_check',
          lockerId,
          lockerNumber,
          lockerSector,
          memberId: ownerId, // owner dobije notif
          cardId,
          status: 'fail',
          reason: 'Kartica nije prepoznata',
        });

        return res.status(401).json({
          authorized: false,
          reason: 'Kartica nije pronađena',
          code: 'CARD_NOT_FOUND',
        });
      }

      const memberDoc = memberSnap.docs[0];
      const memberId = memberDoc.id;
      const memberData = memberDoc.data();
      const memberName = memberData.name || memberData.fullName || null;

      // Check member status
      if (memberData.status !== 'active') {
        await createAccessAttempt({
          source: 'rfid',
          action: 'access_check',
          lockerId,
          lockerNumber,
          lockerSector,
          memberId,
          memberName,
          cardId,
          status: 'fail',
          reason: 'Član nije aktivan',
        });

        return res.status(401).json({
          authorized: false,
          reason: 'Član nije aktivan',
          code: 'MEMBER_INACTIVE',
        });
      }

      // Check membership validity
      const membershipUntil = memberData.membershipValidUntil?.toDate?.() || new Date(0);
      if (membershipUntil < new Date()) {
        await createAccessAttempt({
          source: 'rfid',
          action: 'access_check',
          lockerId,
          lockerNumber,
          lockerSector,
          memberId,
          memberName,
          cardId,
          status: 'fail',
          reason: 'Članstvo je isteklo',
        });

        return res.status(401).json({
          authorized: false,
          reason: 'Članstvo je isteklo',
          code: 'MEMBERSHIP_EXPIRED',
        });
      }

      // Check if locker is assigned to this member
      if (lockerData.assignedMemberId !== memberId) {
        // Notifikuj i pokušavača i vlasnika (ako postoji) kroz accessAttempts
        await createAccessAttempt({
          source: 'rfid',
          action: 'access_check',
          lockerId,
          lockerNumber,
          lockerSector,
          memberId,
          memberName,
          cardId,
          status: 'fail',
          reason: 'Ormar nije dodijeljen ovom članu',
        });

        if (lockerData.assignedMemberId) {
          await createAccessAttempt({
            source: 'rfid',
            action: 'access_check',
            lockerId,
            lockerNumber,
            lockerSector,
            memberId: lockerData.assignedMemberId,
            cardId,
            status: 'fail',
            reason: 'Pokušaj od strane drugog člana',
          });
        }

        return res.status(401).json({
          authorized: false,
          reason: 'Ormar nije asigniran ovom članu',
          code: 'LOCKER_NOT_ASSIGNED',
        });
      }

      // Check locker status
      if (lockerData.status !== 'occupied') {
        await createAccessAttempt({
          source: 'rfid',
          action: 'access_check',
          lockerId,
          lockerNumber,
          lockerSector,
          memberId,
          memberName,
          cardId,
          status: 'fail',
          reason: 'Ormar nije dostupan',
        });

        return res.status(401).json({
          authorized: false,
          reason: 'Ormar nije dostupan',
          code: 'LOCKER_UNAVAILABLE',
        });
      }

      // ACCESS GRANTED
      // Obriši stare sesije za taj ormar i člana
      const oldSessions = await db
        .collection('lockerSessions')
        .where('lockerId', '==', lockerId)
        .where('assignedUserId', '==', memberId)
        .get();

      const batch = db.batch();
      oldSessions.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      // Dodaj jednu aktivnu sesiju
      await db.collection('lockerSessions').add({
        lockerId,
        assignedUserId: memberId,
        authorizedUid: cardId,
        createdAt: ts,
        accessType: 'rfid',
        status: 'active',
      });

      // Upis attempt success (trigger -> notif)
      await createAccessAttempt({
        source: 'rfid',
        action: 'access_check',
        lockerId,
        lockerNumber,
        lockerSector,
        memberId,
        memberName,
        cardId,
        status: 'success',
      });

      return res.status(200).json({
        authorized: true,
        memberId,
        memberName,
        lockerId,
        lockerNumber,
        lockerSector,
        message: 'Pristup dozvoljen',
        code: 'ACCESS_GRANTED',
      });
    } catch (error) {
      console.error('verifyLockerAccess error:', error);
      return res.status(500).json({
        authorized: false,
        reason: 'Greška pri verifikaciji: ' + error.message,
        code: 'ERROR',
      });
    }
  });
});

/**
 * (Opcionalno) Endpoint da IoT ili admin može rezolvovati APP request
 * - koristi attemptId koji je vraćen iz openLocker
 * - status: success/fail
 */
exports.resolveAppOpenAttempt = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') return res.status(200).send();

    try {
      const { attemptId, status, reason } = req.body;

      if (!attemptId || !status || !['success', 'fail'].includes(status)) {
        return res.status(400).json({
          success: false,
          message: 'attemptId i status (success/fail) su obavezni.',
        });
      }

      await resolveAccessAttempt(attemptId, { status, reason: reason || null });

      return res.status(200).json({
        success: true,
        message: 'Attempt je rezolvovan.',
      });
    } catch (error) {
      console.error('resolveAppOpenAttempt error:', error);
      return res.status(500).json({
        success: false,
        message: 'Greška na serveru: ' + error.message,
      });
    }
  });
});

// Health check endpoint
exports.healthCheck = europeFunction.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      await db.collection('lockers').limit(1).get();
      return res.status(200).json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        message: 'Firebase je dostupan',
      });
    } catch (error) {
      return res.status(500).json({
        status: 'error',
        timestamp: new Date().toISOString(),
        message: 'Firebase nije dostupan: ' + error.message,
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
          error: 'Missing cardId parameter',
        });
      }

      const snap = await db.collection('members').where('cardId', '==', cardId).limit(1).get();

      if (snap.empty) {
        return res.status(404).json({
          error: 'Member not found',
        });
      }

      const data = snap.docs[0].data();
      return res.status(200).json({
        memberId: snap.docs[0].id,
        name: data.name,
        cardId: data.cardId,
        status: data.status,
        assignedLockerId: data.assignedLockerId,
        assignedLockerNumber: data.assignedLockerNumber,
      });
    } catch (error) {
      return res.status(500).json({
        error: error.message,
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
          error: 'Missing lockerId parameter',
        });
      }

      const doc = await db.collection('lockers').doc(lockerId).get();

      if (!doc.exists) {
        return res.status(404).json({
          error: 'Locker not found',
        });
      }

      const data = doc.data();
      return res.status(200).json({
        lockerId,
        number: data.number,
        sector: data.sector,
        status: data.status,
        assignedMemberId: data.assignedMemberId,
        currentMember: data.currentMember,
      });
    } catch (error) {
      return res.status(500).json({
        error: error.message,
      });
    }
  });
});
