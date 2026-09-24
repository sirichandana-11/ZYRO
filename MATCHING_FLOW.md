# ZYRO Ride Matching & Allocation Pipeline

## 1. End-to-End Matching Lifecycle

```
Rider App                       Backend Matching Service                      Driver App (Nearby)
   │                                      │                                            │
   │ 1. Request Ride (pickup, drop, fare) │                                            │
   ├─────────────────────────────────────►│                                            │
   │                                      │ 2. Create Ride (status='searching')        │
   │                                      │    requestedAt = serverNow                 │
   │                                      │    expiresAt = serverNow + 120s            │
   │                                      │ 3. Geospatial Index Query                  │
   │                                      │    (Radius <= MATCHING_RADIUS_KM)          │
   │                                      │ 4. Filter Eligible Drivers                 │
   │                                      │ 5. Select Mandatory Backup Driver          │
   │                                      │    (lastRideCompletedAt DESC)              │
   │                                      │ 6. Schedule 120s Timeout Engine            │
   │                                      │ 7. WS Broadcast (ride_request)             │
   │                                      ├───────────────────────────────────────────►│
   │                                      │                                            │ 8. Driver Accepts
   │                                      │ 9. Atomic Transaction (First-Driver-Wins)  │◄─────────────────┤
   │                                      │    status = 'driver_assigned'              │                  │
   │                                      │    driverId = winningDriverUid             │                  │
   │                                      │    driver.isAvailable = false              │                  │
   │                                      │ 10. Cancel 120s Timeout Worker             │                  │
   │ 11. WS Alert (ride_assigned)         │ 11. WS Ack (ride_assigned)                 │                  │
   │◄─────────────────────────────────────┴───────────────────────────────────────────►│                  │
   │ 12. Subscribe to Driver Live GPS     │                                            │                  │
```

---

## 2. Driver Eligibility Specification

A candidate driver is deemed eligible **only** when ALL of the following criteria evaluate to true:

1. **Authentication & Role**: Validated Firebase UID with verified `role === 'driver'`.
2. **Online Status**: `isOnline === true`.
3. **Availability Status**: `isAvailable === true` (not currently engaged in another trip).
4. **Vehicle Type Match**: `driver.vehicleType.toLowerCase() === requestedRideType.toLowerCase()`.
5. **Geospatial Proximity**: Exact Haversine distance from pickup location $\le \text{MATCHING\_RADIUS\_KM}$ (strictly enforced at **2.0 KM** for initial broadcast).
6. **Valid GPS Telemetry**: Real, non-zero latitude $[-90, 90]$, longitude $[-180, 180]$, non-NaN, non-Infinity.
7. **Telemetry Freshness**: Telemetry timestamp must be within `maxLocationAgeSeconds` (default 30 seconds). Stale drivers are excluded from dispatch.
8. **Account Standing**: Not blocked or suspended.

---

## 3. Mandatory Backup Driver Selection Algorithm

To guarantee 100% ride fulfillment reliability, exactly **ONE** mandatory backup driver is pre-selected at ride creation.

### Priority Ranking Rules:
1. **Primary Metric**: `lastRideCompletedAt` descending (the driver who most recently completed a trip).
2. **Deterministic Tie-Breaker 1**: Nearest Haversine distance to pickup location.
3. **Deterministic Tie-Breaker 2**: Alphabetical driver ID (`a.id.localeCompare(b.id)`).

```javascript
// Implementation snippet from backend/src/services/geospatial_matching.js
candidates.sort((a, b) => {
  const timeA = a.lastRideCompletedAt ? new Date(a.lastRideCompletedAt).getTime() : 0;
  const timeB = b.lastRideCompletedAt ? new Date(b.lastRideCompletedAt).getTime() : 0;
  if (timeA !== timeB) return timeB - timeA; // Most recent first
  if (a.distanceKm !== b.distanceKm) return a.distanceKm - b.distanceKm; // Nearest
  return (a.id || '').localeCompare(b.id || ''); // Deterministic
});
```

---

## 4. 120-Second Timeout Invariant

- **Anchor**: `requestedAt` (server timestamp).
- **Expiration**: `expiresAt = requestedAt + 120 seconds`.
- **Timer Execution**: Handled independently on the backend by [timeout_scheduler.js](file:///c:/Users/USER/OneDrive/Desktop/ZYRO/backend/src/jobs/timeout_scheduler.js).
- **At Expiration**:
  - If ride is still `searching`: Automatically assigns `backupDriverId` and sets status to `driver_assigned`.
  - If backup driver became unavailable: Sets status to `no_driver`.
  - **No timer restarts. No secondary matching loop.**
