# ZYRO Live Driver Location Tracking & Telemetry Engine

## 1. High-Frequency Telemetry Pipeline

```
Driver Device (Physical GPS)
   │
   ▼
LocationService.getLivePositionStream(distanceFilterMeters: 10)
   │
   ▼
WebSocketService.sendDriverLocation({ lat, lng, accuracy, speed, heading, rideId })
   │
   ▼ [WSS :8080]
LocationManager (Server-side Ingestion)
   ├─► 1. Identity & Role Check (Verified Driver UID only)
   ├─► 2. Coordinate Validation ([-90..90], [-180..180], Null Island rejection)
   ├─► 3. Dual-Metric Throttle (2.5s update interval OR 10m displacement)
   ├─► 4. In-Memory Store (Fast access latest location)
   └─► 5. Targeted Subscription Dispatch (Send ONLY to ride subscriber sockets)
          │
          ▼ [WSS]
Rider Device (Subscribed to active rideId)
   │
   ▼
ZyroMap (FlutterMap + OpenStreetMap)
   └─► Smooth driver marker animation without recentering camera jitter
```

---

## 2. Server-Side Location Ingestion & Throttling Rules

To prevent malicious battery drainage, network saturation, and unnecessary WebSocket frames, the server enforces:

| Parameter | Configuration | Purpose |
|---|---|---|
| `LOCATION_UPDATE_INTERVAL_MS` | `2500` (2.5 seconds) | Minimum time between broadcast frames. |
| `LOCATION_MIN_DISTANCE_METERS` | `10` (10 meters) | Movement threshold to bypass time throttle for responsive turns. |
| Boundary Guard | $[-90, 90], [-180, 180]$ | Rejects corrupt floats, NaN, and Infinity. |
| Null Island Guard | `lat === 0 && lng === 0` | Rejects GPS initialization default zeroes. |
| Velocity Sanity Check | $< 160\text{ km/h}$ | Rejects impossible GPS jumps (teleportation attacks). |

---

## 3. Targeted Subscription & Privacy Protection

A rider socket **only** receives telemetry when ALL conditions are met:
1. The rider is authenticated via Firebase ID token.
2. The rider has actively subscribed to `rideId`.
3. The server validates that `ride.riderId === authenticatedRiderUid`.
4. The emitting driver is the assigned driver on that specific active trip (`ride.driverId === authenticatedDriverUid`).
5. The ride is in an active state (`DRIVER_ASSIGNED`, `DRIVER_ARRIVING`, `RIDE_STARTED`).

*When the ride transitions to `COMPLETED`, `CANCELLED`, or `NO_DRIVER`, the subscription is immediately terminated.*
