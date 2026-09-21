# ZYRO Production Deployment & DevOps Guide

## 1. Environment Profiles

| Environment | Purpose | Configuration |
|---|---|---|
| **Development (`development`)** | Local dev, unit tests, mock token support. | `NODE_ENV=development`, local in-memory pubsub, mock tokens allowed. |
| **Staging (`staging`)** | Pre-production testing with real Firebase project. | `NODE_ENV=staging`, Firebase Admin SDK initialized with staging service account. |
| **Production (`production`)** | Live high-availability cluster. | `NODE_ENV=production`, Redis PubSub enabled, strict token validation, zero mock tokens. |

---

## 2. Server Deployment Architecture

```
                                  Internet
                                     │
                                     ▼
                     ┌───────────────────────────────┐
                     │   Cloud Load Balancer (HTTPS) │
                     │   - SSL Termination           │
                     │   - Geo-DNS / DDoS Shield     │
                     └───────────────┬───────────────┘
                                     │
                      ┌──────────────┴──────────────┐
                      ▼                             ▼
        ┌───────────────────────────┐ ┌───────────────────────────┐
        │  Cloud Run (API Gateway)  │ │  Cloud Run (WebSocket)    │
        │  Instance Auto-Scaling    │ │  Instance Auto-Scaling    │
        └─────────────┬─────────────┘ └─────────────┬─────────────┘
                      │                             │
                      └──────────────┬──────────────┘
                                     │
                                     ▼
                      ┌─────────────────────────────┐
                      │  Memorystore for Redis      │
                      │  (Pub/Sub & Location Cache) │
                      └──────────────┬──────────────┘
                                     │
                                     ▼
                      ┌─────────────────────────────┐
                      │  Cloud Firestore Enterprise │
                      │  (Multi-Region Database)    │
                      └─────────────────────────────┘
```

---

## 3. Deployment Steps

### Step 1: Configure Environment Variables
Copy `.env.example` to `.env` in `websocket-server/`:
```bash
cp websocket-server/.env.example websocket-server/.env
```
Set production credentials:
```env
PORT=8080
HOST=0.0.0.0
NODE_ENV=production
LOCATION_UPDATE_INTERVAL_MS=2500
LOCATION_MIN_DISTANCE_METERS=10
MATCHING_RADIUS_KM=10
FIREBASE_PROJECT_ID=your-production-firebase-project
FIREBASE_SERVICE_ACCOUNT=/secrets/firebase-service-account.json
```

### Step 2: Build & Deploy Container
```bash
# Build Docker image
docker build -t gcr.io/zyro-production/websocket-gateway:latest -f websocket-server/Dockerfile websocket-server/

# Deploy to Cloud Run with WebSocket support enabled
gcloud run deploy zyro-websocket-gateway \
  --image gcr.io/zyro-production/websocket-gateway:latest \
  --platform managed \
  --region asia-south1 \
  --allow-unauthenticated \
  --port 8080 \
  --min-instances 2 \
  --max-instances 20 \
  --cpu 2 \
  --memory 2Gi \
  --session-affinity
```

### Step 3: Health Verification
```bash
curl https://api.zyro.app/health
# Response: {"status":"healthy","timestamp":1726765000000,"activeConnections":0,"onlineDrivers":0}
```
