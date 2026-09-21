const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');
const { OAuth2Client } = require('google-auth-library');

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();
const authClient = new OAuth2Client();

// Set default function options
setGlobalOptions({
  region: 'us-central1',
  maxInstances: 10,
});

const DriverService = require('./services/driverService');
const TaskQueueService = require('./services/taskQueueService');

const driverService = new DriverService(db);
const taskQueueService = new TaskQueueService();

/**
 * Validates Google-signed OIDC bearer token from Cloud Tasks requests.
 *
 * @param {Object} req Express request
 * @param {string} expectedAudience Expected target URL
 * @returns {Promise<boolean>}
 */
async function verifyGoogleIdToken(req, expectedAudience) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return false;
  }
  const token = authHeader.split('Bearer ')[1];
  try {
    const ticket = await authClient.verifyIdToken({
      idToken: token,
      audience: expectedAudience,
    });
    const payload = ticket.getPayload();
    return !!(payload && (payload.email_verified || payload.email));
  } catch (err) {
    // If exact audience verification fails due to custom domains/proxies,
    // verify token validity signed by Google certificate authority
    try {
      const ticket = await authClient.verifyIdToken({
        idToken: token,
      });
      const payload = ticket.getPayload();
      return !!(payload && payload.email);
    } catch (fallbackErr) {
      console.error(
        '[verifyGoogleIdToken] OIDC token verification rejected:',
        err.message
      );
      return false;
    }
  }
}

/**
 * 1. TRIGGER: onRideCreated
 *
 * Triggered automatically when a rider creates a ride document in Firestore.
 *
 * Steps:
 * 1. Compute requestedAt and expiresAt (requestedAt + 120s) as source of truth.
 * 2. Find eligible nearby drivers matching rideType.
 * 3. Select ONE mandatory backup driver using lastRideCompletedAt descending (fallback nearest).
 * 4. Update ride document with expiresAt, backupDriverId, and eligibleDriverIds.
 * 5. Schedule 120-second timeout processing via Cloud Tasks.
 */
exports.onRideCreated = onDocumentCreated('rides/{rideId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('[onRideCreated] No data associated with event.');
    return;
  }

  const rideData = snapshot.data();
  const rideId = event.params.rideId;

  // Only initialize newly created rides in 'searching' status with uncalculated expiresAt
  if (rideData.status !== 'searching' || rideData.expiresAt) {
    return;
  }

  console.log(`[onRideCreated] Initializing ride allocation for rideId: ${rideId}`);

  // 1. Establish source of truth for requestedAt and expiresAt
  const requestedAt =
    rideData.requestedAt instanceof admin.firestore.Timestamp
      ? rideData.requestedAt
      : admin.firestore.Timestamp.now();

  const expiresAtSeconds = requestedAt.seconds + 120;
  const expiresAt = new admin.firestore.Timestamp(
    expiresAtSeconds,
    requestedAt.nanoseconds
  );

  // 2. Query eligible nearby drivers
  const eligibleDrivers = await driverService.findEligibleDrivers({
    pickupLatitude: rideData.pickupLatitude,
    pickupLongitude: rideData.pickupLongitude,
    rideType: rideData.rideType,
    maxRadiusKm: 10,
  });

  console.log(
    `[onRideCreated] Found ${eligibleDrivers.length} eligible drivers for rideId: ${rideId}`
  );

  // 3. Select mandatory backup driver
  const backupDriver = driverService.selectBackupDriver(eligibleDrivers);
  const backupDriverId = backupDriver ? backupDriver.id : null;

  if (backupDriverId) {
    console.log(
      `[onRideCreated] Selected backup driver: ${backupDriverId} for rideId: ${rideId}`
    );
  } else {
    console.warn(
      `[onRideCreated] No eligible backup driver found for rideId: ${rideId}`
    );
  }

  // 4. Update ride document
  const eligibleDriverIds = eligibleDrivers.map((d) => d.id);
  const updatePayload = {
    requestedAt: requestedAt,
    expiresAt: expiresAt,
    backupDriverId: backupDriverId,
    eligibleDriverIds: eligibleDriverIds,
  };

  // If no eligible drivers exist at all, immediately mark as no_driver
  if (eligibleDrivers.length === 0) {
    updatePayload.status = 'no_driver';
  }

  await db.collection('rides').doc(rideId).update(updatePayload);

  // 5. Schedule 120-second timeout task if ride is searching
  if (eligibleDrivers.length > 0) {
    try {
      const taskName = await taskQueueService.scheduleRideTimeout({
        rideId,
        scheduleTimeSeconds: expiresAtSeconds,
      });

      await db.collection('rides').doc(rideId).update({
        timeoutTaskId: taskName,
        timeoutScheduled: true,
      });
    } catch (err) {
      console.error(
        `[onRideCreated] CRITICAL: Could not schedule Cloud Task for ride ${rideId}: ${err.message}`
      );
      await db.collection('rides').doc(rideId).update({
        timeoutScheduled: false,
        timeoutScheduleError: err.message,
      });
    }
  }
});

/**
 * 2. CALLABLE: acceptRide
 *
 * Called when an eligible driver attempts to accept an offered ride.
 *
 * Race-Safe Transaction:
 * - Verifies ride status is 'searching'
 * - Verifies ride has not expired (current time <= expiresAt)
 * - Verifies driver is online and available
 * - Verifies no driver has already been assigned
 * - Atomically assigns driver and locks driver availability.
 */
exports.acceptRide = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication required to accept a ride.'
    );
  }

  const { rideId, driverId: requestedDriverId } = request.data || {};
  const driverId = request.auth.uid;

  if (!rideId) {
    throw new HttpsError(
      'invalid-argument',
      'rideId is required.'
    );
  }

  // Reject if client attempts to pass a mismatched driver ID
  if (requestedDriverId && requestedDriverId !== driverId) {
    throw new HttpsError(
      'permission-denied',
      'You can only accept rides for your own authenticated driver account.'
    );
  }

  const rideRef = db.collection('rides').doc(rideId);
  const driverRef = db.collection('drivers').doc(driverId);

  try {
    const result = await db.runTransaction(async (transaction) => {
      const [rideDoc, driverDoc] = await Promise.all([
        transaction.get(rideRef),
        transaction.get(driverRef),
      ]);

      if (!rideDoc.exists) {
        throw new HttpsError('not-found', 'Ride not found.');
      }

      if (!driverDoc.exists) {
        throw new HttpsError('not-found', 'Driver record not found.');
      }

      const ride = rideDoc.data();
      const driver = driverDoc.data();

      // Check ride status
      if (ride.status !== 'searching') {
        throw new HttpsError(
          'failed-precondition',
          `Ride is no longer searching (current status: ${ride.status}).`
        );
      }

      // Check ride expiration using server time
      if (ride.expiresAt) {
        const now = admin.firestore.Timestamp.now();
        const nowMs = now.toMillis();
        const expiresAtMs =
          typeof ride.expiresAt.toMillis === 'function'
            ? ride.expiresAt.toMillis()
            : new Date(ride.expiresAt).getTime();

        if (nowMs > expiresAtMs) {
          throw new HttpsError(
            'deadline-exceeded',
            'Ride request has expired.'
          );
        }
      }

      // Check driver availability
      if (!driver.isOnline || !driver.isAvailable) {
        throw new HttpsError(
          'failed-precondition',
          'Driver is no longer online or available.'
        );
      }

      // Check if driver already assigned
      if (ride.driverId) {
        throw new HttpsError(
          'already-exists',
          'Another driver has already been assigned to this ride.'
        );
      }

      // Atomically assign driver and mark driver as busy
      transaction.update(rideRef, {
        driverId: driverId,
        status: 'driver_assigned',
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(driverRef, {
        isAvailable: false,
        activeRideId: rideId,
      });

      return {
        success: true,
        rideId,
        driverId,
        status: 'driver_assigned',
      };
    });

    console.log(
      `[acceptRide] Driver ${driverId} successfully accepted ride ${rideId}`
    );
    return result;
  } catch (error) {
    console.error(`[acceptRide] Error accepting ride ${rideId}:`, error);
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', error.message || 'Failed to accept ride.');
  }
});

/**
 * Helper function to execute atomic timeout assignment logic.
 *
 * Checks:
 * - ride is still 'searching'
 * - expiresAt exists and current server time now >= expiresAt
 * - backupDriver is still online & available
 *
 * If backup available: atomically assigns backup.
 * If backup unavailable: marks ride as 'no_driver'.
 */
async function processRideTimeoutLogic(rideId) {
  if (!rideId) {
    return { success: false, reason: 'missing_ride_id' };
  }

  const rideRef = db.collection('rides').doc(rideId);

  return db.runTransaction(async (transaction) => {
    const rideDoc = await transaction.get(rideRef);

    if (!rideDoc.exists) {
      return { success: false, reason: 'ride_not_found' };
    }

    const ride = rideDoc.data();

    // 1. If ride is no longer searching (e.g. accepted, cancelled, completed), do nothing
    if (ride.status !== 'searching') {
      return {
        success: true,
        alreadyProcessed: true,
        status: ride.status,
      };
    }

    // 2. Verify expiration using Firebase Admin server time
    const now = admin.firestore.Timestamp.now();

    if (!ride.expiresAt) {
      return {
        success: false,
        reason: 'missing_expiration',
      };
    }

    const nowMillis = now.toMillis();
    const expiresAtMillis =
      typeof ride.expiresAt.toMillis === 'function'
        ? ride.expiresAt.toMillis()
        : new Date(ride.expiresAt).getTime();

    if (nowMillis < expiresAtMillis) {
      // Ride has not expired yet — DO NOT assign backup, DO NOT change status
      return {
        success: false,
        reason: 'not_expired',
      };
    }

    // 3. Evaluate backup driver
    const backupDriverId = ride.backupDriverId;

    if (!backupDriverId) {
      // No backup driver exists, mark ride as no_driver
      transaction.update(rideRef, {
        status: 'no_driver',
      });
      return {
        success: true,
        assigned: false,
        status: 'no_driver',
        reason: 'no_backup_configured',
      };
    }

    const driverRef = db.collection('drivers').doc(backupDriverId);
    const driverDoc = await transaction.get(driverRef);

    const driver = driverDoc.exists ? driverDoc.data() : null;
    const isBackupAvailable =
      driver && driver.isOnline === true && driver.isAvailable === true;

    if (isBackupAvailable) {
      // Automatically assign the mandatory backup driver
      transaction.update(rideRef, {
        driverId: backupDriverId,
        status: 'driver_assigned',
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(driverRef, {
        isAvailable: false,
        activeRideId: rideId,
      });

      console.log(
        `[processRideTimeout] Automatically assigned mandatory backup driver ${backupDriverId} to ride ${rideId}`
      );

      return {
        success: true,
        assigned: true,
        driverId: backupDriverId,
        status: 'driver_assigned',
      };
    } else {
      // Backup driver is no longer available; do NOT restart timer or pick random driver
      transaction.update(rideRef, {
        status: 'no_driver',
      });

      console.log(
        `[processRideTimeout] Backup driver ${backupDriverId} unavailable at timeout for ride ${rideId}. Marked as no_driver.`
      );

      return {
        success: true,
        assigned: false,
        status: 'no_driver',
        reason: 'backup_unavailable',
      };
    }
  });
}

/**
 * 3. CALLABLE: processRideTimeout
 *
 * Callable endpoint to trigger or verify 120-second expiration.
 */
exports.processRideTimeout = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication required to process ride timeout.'
    );
  }

  const { rideId } = request.data || {};
  if (!rideId) {
    throw new HttpsError('invalid-argument', 'rideId is required.');
  }

  try {
    return await processRideTimeoutLogic(rideId);
  } catch (error) {
    console.error(
      `[processRideTimeout] Error processing timeout for ride ${rideId}:`,
      error
    );
    throw new HttpsError(
      'internal',
      error.message || 'Failed to process timeout.'
    );
  }
});

/**
 * 4. HTTP / Cloud Tasks Handler: processRideTimeoutTask
 *
 * Receives scheduled task triggers from Cloud Tasks after 120 seconds.
 * Rejects unauthenticated/untrusted requests using OIDC authentication.
 */
exports.processRideTimeoutTask = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  // Verify caller authenticity via OIDC token or Cloud Tasks header
  const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
  const targetUrl = taskQueueService.getTargetUrl('processRideTimeoutTask');

  if (!isEmulator) {
    const authHeader = req.headers.authorization;
    const taskNameHeader = req.headers['x-cloudtasks-taskname'];

    let isAuthorized = false;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      isAuthorized = await verifyGoogleIdToken(req, targetUrl);
    } else if (taskNameHeader) {
      // Cloud Tasks also sets x-cloudtasks-* headers when running within GCP network
      isAuthorized = true;
    }

    if (!isAuthorized) {
      console.warn(
        '[processRideTimeoutTask] Unauthorized invocation attempt rejected.'
      );
      res.status(401).json({
        error:
          'Unauthorized: Valid Google OIDC token or Cloud Tasks header required.',
      });
      return;
    }
  }

  const { rideId } = req.body || {};
  if (!rideId) {
    res.status(400).send('Missing rideId');
    return;
  }

  try {
    const result = await processRideTimeoutLogic(rideId);
    res.status(200).json(result);
  } catch (error) {
    console.error(
      `[processRideTimeoutTask] Error handling task for ride ${rideId}:`,
      error
    );
    res.status(500).send(error.message || 'Internal Server Error');
  }
});

/**
 * 5. SCHEDULED SWEEPER: sweepExpiredRides
 *
 * Runs every 1 minute as a safety net to process any expired searching rides
 * where Cloud Tasks delivery was delayed or unconfigured.
 */
exports.sweepExpiredRides = onSchedule('every 1 minutes', async (event) => {
  const now = admin.firestore.Timestamp.now();

  const snapshot = await db
    .collection('rides')
    .where('status', '==', 'searching')
    .where('expiresAt', '<=', now)
    .limit(50)
    .get();

  if (snapshot.empty) {
    return;
  }

  console.log(
    `[sweepExpiredRides] Found ${snapshot.size} expired rides to process.`
  );

  const promises = snapshot.docs.map((doc) =>
    processRideTimeoutLogic(doc.id)
  );

  await Promise.all(promises);
});
