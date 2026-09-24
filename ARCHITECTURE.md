# ZYRO Production Architecture Specification

## 1. System Overview

ZYRO is designed as a horizontally scalable, event-driven ride-hailing platform with strict separation between **Durable Authoritative State** (Cloud Firestore / Relational DB) and **High-Speed Volatile Telemetry** (WebSocket + Realtime Location Engine).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Rider & Driver Applications                     │
│                        (Flutter iOS / Android / Web)                   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                         HTTPS API  │  WSS (TLS 1.3)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Cloud Load Balancer / API Gateway               │
│                        (SSL Termination, Rate Limiting)                │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼                                ▼
┌──────────────────────────────────────┐ ┌───────────────────────────────┐
│     Stateless Backend Services       │ │  Distributed WebSocket Cluster│
│     (Cloud Run / Microservices)      │ │     (Node.js / ws Nodes)      │
│  - Ride State Machine                │ │  - Auth & Socket Mapping      │
│  - Geospatial Matching Engine        │ │  - Targeted Subscriptions     │
│  - Autonomous 120s Timeout Worker    │ │  - Realtime Location Gateway  │
│  - Idempotency & Rate Limiters       │ │  - Heartbeat / Liveness       │
└───────────────────┬──────────────────┘ └───────────────┬───────────────┘
                    │                                    │
                    │               Pub/Sub Broker       │
                    ├────────────────────────────────────┤
                    │   (Redis Pub/Sub / Cloud Pub/Sub)  │
                    │                                    │
                    ▼                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                 Authoritative Persistent Data Layer                    │
│                 (Cloud Firestore / Cloud SQL PostGIS)                  │
│  - Atomic Transactions (First-Driver-Wins)                             │
│  - Rides Collection & Immutable Audit Trails                           │
│  - Drivers Master Availability & Profiles                              │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Components & Responsibilities

### 2.1. Client Applications (Flutter)
- **Rider Experience**: Real GPS pickup detection, interactive OpenStreetMap rendering, trip destination search, ride allocation timer tracking, and live driver marker animation.
- **Driver Dashboard**: Online/offline toggle, GPS stream broadcasting (10m filter), incoming dispatch modal, atomic ride acceptance, and active route navigation.

### 2.2. WebSocket Gateway Cluster
- **Port**: `8080` (HTTP + WSS).
- **Zero-Trust Auth**: Rejects unauthenticated connections; extracts verified `uid` and `role` via Firebase Admin ID token verification.
- **Connection Manager**: Maps `socket -> user` and `user -> Set<socket>` for seamless multi-device sessions.
- **Location Ingestion**: Validates coordinates, filters Null Island (`0,0`), enforces 2.5s time + 10m displacement throttling, and routes telemetry exclusively to authorized ride subscribers.

### 2.3. Stateless Backend Domain Services
- **`RideStateMachine`**: Enforces legal state machine transitions:
  $$\text{CREATED} \to \text{SEARCHING} \to \text{DRIVER\_ASSIGNED} \to \text{DRIVER\_ARRIVING} \to \text{DRIVER\_ARRIVED} \to \text{RIDE\_STARTED} \to \text{COMPLETED}$$
  Terminal states (`COMPLETED`, `CANCELLED`, `NO_DRIVER`) are immutable.
- **`GeospatialMatchingService`**: Evaluates driver eligibility within `MATCHING_RADIUS_KM` (strictly **2.0 KM** for initial broadcast) using spatial bounding boxes, vehicle compatibility, and a 30s telemetry freshness filter.
- **`TimeoutScheduler`**: Background worker managing the 120-second allocation expiry independent of client widget lifecycles.
- **`IdempotencyManager`**: Deduplicates mutations via cached response fingerprints with a 24-hour TTL.

### 2.4. Data Invariant: Dual-Channel Architecture
| Channel | Technology | Scope & Authority |
|---|---|---|
| **Authoritative Channel** | Cloud Firestore | Persistent ride state, user profiles, transactional driver assignment, financial transactions. |
| **Realtime Channel** | WebSocket Cluster | High-frequency GPS updates, UI dispatch alerts, fast optimistic marker movement. |

*Critical Security Invariant: WebSocket events are notifications, never the authoritative assignment.*
