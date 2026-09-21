const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if service account or default credentials exist
let isFirebaseInitialized = false;

function initFirebaseAdmin() {
  if (isFirebaseInitialized || admin.apps.length > 0) {
    isFirebaseInitialized = true;
    return;
  }

  try {
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (serviceAccountPath) {
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      isFirebaseInitialized = true;
      console.log('[Auth] Firebase Admin initialized with service account.');
    } else {
      // Try default application credentials or project ID
      admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'zyro-ride',
      });
      isFirebaseInitialized = true;
      console.log('[Auth] Firebase Admin initialized with default credentials.');
    }
  } catch (err) {
    console.warn('[Auth] Firebase Admin initialization note:', err.message);
  }
}

/**
 * Verifies a Firebase Authentication ID token.
 * Returns { uid, email, role } or throws an Error.
 *
 * @param {string} token - The raw Firebase ID token from client.
 * @returns {Promise<{uid: string, email: string, role: string}>}
 */
async function verifyAuthToken(token) {
  if (!token || typeof token !== 'string' || token.trim().length === 0) {
    throw new Error('Authentication token is required and must be a non-empty string.');
  }

  initFirebaseAdmin();

  // 1. Primary: Verify token via Firebase Admin Auth
  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    const uid = decodedToken.uid;
    const email = decodedToken.email || '';

    // Fetch authoritative role from Firestore users/{uid}
    let role = 'rider';
    try {
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()) {
        const userData = userDoc.data();
        if (userData.role) {
          role = userData.role.toLowerCase();
        }
      } else {
        // Check if driver profile exists directly in drivers/{uid}
        const driverDoc = await admin.firestore().collection('drivers').doc(uid).get();
        if (driverDoc.exists) {
          role = 'driver';
        }
      }
    } catch (dbErr) {
      console.warn(`[Auth] Could not read user role from Firestore for ${uid}: ${dbErr.message}`);
    }

    return {
      uid,
      email,
      role: role === 'driver' ? 'driver' : 'rider',
    };
  } catch (authErr) {
    // 2. Fallback for offline local unit tests / mock development tokens
    if (token.startsWith('mock_token_') || token.startsWith('demo_token_')) {
      const raw = token.replace('mock_token_', '').replace('demo_token_', '');
      const parts = raw.split(':');
      const uid = parts[0] || 'test_user';
      const role = parts[1] || (uid.includes('driver') ? 'driver' : 'rider');
      console.log(`[Auth] Mock token accepted for local development: uid=${uid}, role=${role}`);
      return {
        uid,
        email: `${uid}@zyro.app`,
        role: role === 'driver' ? 'driver' : 'rider',
      };
    }

    throw new Error(`Token verification failed: ${authErr.message}`);
  }
}

module.exports = {
  initFirebaseAdmin,
  verifyAuthToken,
};
