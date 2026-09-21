# ZYRO Real-Time WebSocket Server

The real-time WebSocket communication server for the ZYRO ride-hailing application.

## Overview
- **Transport**: Sub-second bidirectional WebSocket protocol via Node.js `ws`.
- **Authentication**: Zero-trust Firebase ID token authentication (`verifyIdToken`).
- **Authorization**: Role-based access control (`rider` vs `driver`).
- **Location Pipeline**: Live GPS streaming with 2.5s throttling and targeted routing to authorized ride subscribers.
- **Authoritative Source of Truth**: Cloud Firestore and atomic transactions always remain authoritative for ride assignment and state.

## Installation & Setup

```bash
cd websocket-server
npm install
```

## Running the Server

### Development Mode
```bash
npm start
# Server starts on http://localhost:8080 (ws://localhost:8080)
```

### Running Unit Tests
```bash
npm test
```

## Environment Configuration
You can optionally create a `.env` file:
```env
PORT=8080
HOST=0.0.0.0
LOCATION_UPDATE_INTERVAL_MS=2500
FIREBASE_PROJECT_ID=zyro-ride
# Optional for production:
# FIREBASE_SERVICE_ACCOUNT=./service-account.json
```

## Message Protocol
Every message exchanged contains `type`, `messageId`, and `timestamp`.

### Client -> Server:
- `authenticate`: Sends Firebase ID token.
- `driver_online`: Marks driver online with vehicleType.
- `driver_offline`: Marks driver offline.
- `driver_location`: Emits latitude, longitude, and accuracy.
- `subscribe_ride`: Subscribes to events for a specific `rideId`.
- `unsubscribe_ride`: Unsubscribes from a `rideId`.
- `ping`: Keep-alive heartbeat frame.

### Server -> Client:
- `authenticated`: Confirms identity with verified UID and role.
- `authentication_error`: Reports rejected authentication.
- `driver_location`: Forwards real-time driver coordinates to authorized riders.
- `ride_request`: Notifies online eligible drivers of incoming ride offers.
- `ride_assigned`: Notifies rider of driver assignment confirmation.
- `ride_status_changed`: Broadcasts status transitions (`driver_arriving`, `ride_started`, `completed`, `cancelled`).
- `pong`: Heartbeat response.
