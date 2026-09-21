# ZYRO Application Security & Threat Model

## 1. Zero-Trust Identity & Token Verification

1. **Authentication Handshake**: Every WebSocket connection and REST request must present a cryptographically valid Firebase ID Token.
2. **Server Verification**: The server invokes `admin.auth().verifyIdToken(token)` via the Firebase Admin SDK.
3. **Role Enforcement**: User roles are resolved from Firestore master records (`users/{uid}.role` or `drivers/{uid}`).
4. **No Client Trust**: Client-supplied `uid`, `role`, `driverId`, and `riderId` fields inside payload JSON are strictly ignored; identity is derived exclusively from the authenticated socket session.

---

## 2. Threat Mitigation Matrix

| Threat / Attack Vector | Risk | Mitigation Strategy |
|---|---|---|
| **Driver Impersonation** | Attacker emits location updates under another driver's ID. | Driver UID is locked to the authenticated socket. Payloads claiming other driver IDs are rejected. |
| **Rider Eavesdropping** | Attacker subscribes to another rider's trip to spy on coordinates. | `handleSubscribeRide()` strictly verifies `ride.riderId === authenticatedUid`. |
| **Fabricated Assignment** | Malicious driver emits `ride_assigned` directly over WebSocket. | Direct client-to-client assignment over WS is rejected; assignments must commit to Firestore transactions first. |
| **Simultaneous Acceptance Race** | Two drivers accept the same ride at the exact same millisecond. | Atomic `_firestore.runTransaction()` with early status checks ensures strictly one winner. |
| **GPS Spoofing / Teleportation** | Driver transmits fake coordinates across continents. | Server rejects out-of-bounds coordinates, Null Island, and velocity anomalies ($> 160\text{ km/h}$). |
| **Replay Attacks / Duplicate Creation** | Repeated ride creation on network jitter. | `IdempotencyManager` deduplicates requests using unique idempotency keys with a 24-hour TTL. |
| **DoS / WebSocket Flooding** | Attacker spams millions of GPS messages per second. | Dual throttling (2.5s time + 10m displacement) and rate limiters drop excess frames. |

---

## 3. Safe Logging Protocol

Under zero circumstances will the backend or client log:
- Plaintext passwords or PINs.
- Raw Firebase Auth ID tokens or refresh tokens.
- Private service account keys or environment secrets.
- Unredacted customer payment information.
