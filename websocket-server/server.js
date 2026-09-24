require('dotenv').config();
const http = require('http');
const { WebSocketServer } = require('ws');
const { initFirebaseAdmin, verifyAuthToken } = require('./auth');
const ConnectionManager = require('./connection_manager');
const LocationManager = require('./location_manager');
const RideEventManager = require('./ride_events');

const PORT = parseInt(process.env.PORT, 10) || 8085;
const HOST = process.env.HOST || '0.0.0.0';

// Initialize core managers
initFirebaseAdmin();
const connectionManager = new ConnectionManager();
const locationManager = new LocationManager(connectionManager);
const rideEventManager = new RideEventManager(connectionManager);

// Create HTTP server for health checking & HTTP triggers
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  // Health check endpoint
  if (url.pathname === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'healthy',
        timestamp: Date.now(),
        activeConnections: connectionManager.activeCount,
        onlineDrivers: connectionManager.onlineDrivers.size,
      })
    );
    return;
  }

  // HTTP webhook for ride request broadcast
  if (url.pathname === '/api/events/ride-request' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const data = JSON.parse(body);
        const count = rideEventManager.broadcastRideRequest(data);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, notifiedDrivers: count }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  // HTTP webhook for ride assignment broadcast
  if (url.pathname === '/api/events/ride-assigned' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', () => {
      try {
        const { rideId, ...assignedData } = JSON.parse(body);
        const count = rideEventManager.notifyRideAssigned(rideId, assignedData);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true, notifiedSubscribers: count }));
      } catch (err) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: err.message }));
      }
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Endpoint not found' }));
});

// Create WebSocket server attached to HTTP server
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
  const connectionInfo = connectionManager.register(ws);
  const clientIp = req.socket.remoteAddress;
  console.log(`[WS] Client connected (ID: ${connectionInfo.connectionId.substring(0, 8)}, IP: ${clientIp})`);

  // Handle incoming messages
  ws.on('message', async (rawMessage) => {
    connectionInfo.lastSeen = Date.now();
    connectionInfo.isAlive = true;

    let message;
    try {
      message = JSON.parse(rawMessage.toString());
    } catch (err) {
      connectionManager.send(ws, {
        type: 'error',
        payload: { message: 'Malformed JSON payload.' },
      });
      return;
    }

    const { type, messageId, payload = {} } = message;

    if (!type || typeof type !== 'string') {
      connectionManager.send(ws, {
        type: 'error',
        messageId,
        payload: { message: 'Message type is required.' },
      });
      return;
    }

    try {
      switch (type) {
        // 1. Authenticate connection with Firebase ID token
        case 'authenticate': {
          const token = payload.token;
          try {
            const authResult = await verifyAuthToken(token);
            connectionManager.authenticate(ws, authResult);

            console.log(`[WS] Authenticated: uid=${authResult.uid}, role=${authResult.role}`);
            connectionManager.send(ws, {
              type: 'authenticated',
              messageId,
              payload: {
                uid: authResult.uid,
                role: authResult.role,
              },
            });
          } catch (authError) {
            console.warn(`[WS] Auth rejected: ${authError.message}`);
            connectionManager.send(ws, {
              type: 'authentication_error',
              messageId,
              payload: { message: authError.message },
            });
          }
          break;
        }

        // 2. Driver Go Online
        case 'driver_online': {
          if (!connectionInfo.isAuthenticated || connectionInfo.role !== 'driver') {
            connectionManager.send(ws, {
              type: 'error',
              messageId,
              payload: { message: 'Unauthorized. Must be an authenticated driver.' },
            });
            return;
          }
          connectionManager.setDriverOnline(connectionInfo.uid, payload.vehicleType || 'bike');
          console.log(`[WS] Driver online: ${connectionInfo.uid}`);
          connectionManager.send(ws, {
            type: 'driver_online_ack',
            messageId,
            payload: { isOnline: true },
          });
          break;
        }

        // 3. Driver Go Offline
        case 'driver_offline': {
          if (connectionInfo.isAuthenticated) {
            connectionManager.setDriverOffline(connectionInfo.uid);
            console.log(`[WS] Driver offline: ${connectionInfo.uid}`);
            connectionManager.send(ws, {
              type: 'driver_offline_ack',
              messageId,
              payload: { isOnline: false },
            });
          }
          break;
        }

        // 4. Live Driver GPS Location Frame
        case 'driver_location': {
          await locationManager.handleDriverLocation(ws, connectionInfo, payload);
          break;
        }

        // 5. Subscribe to Ride Events
        case 'subscribe_ride': {
          await rideEventManager.handleSubscribeRide(ws, connectionInfo, payload);
          break;
        }

        // 6. Unsubscribe from Ride Events
        case 'unsubscribe_ride': {
          rideEventManager.handleUnsubscribeRide(ws, connectionInfo, payload);
          break;
        }

        // 7. Ride Cancelled Notification
        case 'ride_cancelled': {
          const rideId = payload.rideId;
          if (rideId) {
            rideEventManager.notifyRideCancelled(rideId, payload);
          }
          break;
        }

        // 8. Ping / Heartbeat
        case 'ping': {
          connectionManager.send(ws, {
            type: 'pong',
            messageId,
            timestamp: Date.now(),
          });
          break;
        }

        // 9. Pong from client
        case 'pong': {
          connectionInfo.isAlive = true;
          break;
        }

        default: {
          connectionManager.send(ws, {
            type: 'error',
            messageId,
            payload: { message: `Unknown event type: ${type}` },
          });
        }
      }
    } catch (handlerErr) {
      console.error(`[WS] Handler error on event "${type}":`, handlerErr);
      connectionManager.send(ws, {
        type: 'error',
        messageId,
        payload: { message: 'Internal server error processing event.' },
      });
    }
  });

  // Handle client ping frame
  ws.on('pong', () => {
    connectionInfo.isAlive = true;
  });

  // Handle socket close
  ws.on('close', () => {
    console.log(`[WS] Client disconnected (ID: ${connectionInfo.connectionId.substring(0, 8)})`);
    connectionManager.unregister(ws);
  });

  // Handle socket errors
  ws.on('error', (err) => {
    console.error(`[WS] Socket error (${connectionInfo.connectionId.substring(0, 8)}):`, err.message);
  });
});

// Periodic Heartbeat to terminate dead TCP connections (every 30s)
const HEARTBEAT_INTERVAL_MS = 30000;
const heartbeatInterval = setInterval(() => {
  for (const [ws, info] of connectionManager.connections) {
    if (!info.isAlive) {
      console.log(`[WS] Terminating stale connection: ${info.connectionId.substring(0, 8)}`);
      connectionManager.unregister(ws);
      ws.terminate();
      continue;
    }
    info.isAlive = false;
    ws.ping();
  }
}, HEARTBEAT_INTERVAL_MS);

wss.on('close', () => {
  clearInterval(heartbeatInterval);
});

// Start Server
server.listen(PORT, HOST, () => {
  console.log('====================================================');
  console.log(`ZYRO WebSocket Server running on http://${HOST}:${PORT}`);
  console.log(`WebSocket endpoint: ws://localhost:${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log('====================================================');
});

module.exports = {
  server,
  wss,
  connectionManager,
  locationManager,
  rideEventManager,
};
