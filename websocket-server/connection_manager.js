const crypto = require('crypto');

class ConnectionManager {
  constructor() {
    // ws -> ConnectionInfo
    this.connections = new Map();
    // uid -> Set<ws>
    this.userConnections = new Map();
    // rideId -> Set<ws>
    this.rideSubscriptions = new Map();
    // driverId -> { isOnline: boolean, vehicleType: string, lastSeen: number }
    this.onlineDrivers = new Map();
  }

  /**
   * Registers a new raw WebSocket connection.
   */
  register(ws) {
    const connectionId = crypto.randomUUID();
    const info = {
      connectionId,
      ws,
      uid: null,
      role: null,
      email: null,
      isAuthenticated: false,
      isAlive: true,
      connectedAt: Date.now(),
      lastSeen: Date.now(),
      subscriptions: new Set(),
    };
    this.connections.set(ws, info);
    return info;
  }

  /**
   * Authenticates an existing connection with verified Firebase credentials.
   */
  authenticate(ws, { uid, role, email }) {
    const info = this.connections.get(ws);
    if (!info) return null;

    info.uid = uid;
    info.role = role;
    info.email = email;
    info.isAuthenticated = true;
    info.lastSeen = Date.now();

    // Map uid -> Set<ws>
    if (!this.userConnections.has(uid)) {
      this.userConnections.set(uid, new Set());
    }
    this.userConnections.get(uid).add(ws);

    return info;
  }

  /**
   * Marks a driver as online.
   */
  setDriverOnline(uid, vehicleType = 'bike') {
    this.onlineDrivers.set(uid, {
      isOnline: true,
      vehicleType,
      lastSeen: Date.now(),
    });
  }

  /**
   * Marks a driver as offline.
   */
  setDriverOffline(uid) {
    this.onlineDrivers.delete(uid);
  }

  /**
   * Subscribes a connection to a specific ride's real-time events.
   */
  subscribeToRide(ws, rideId) {
    const info = this.connections.get(ws);
    if (!info) return false;

    info.subscriptions.add(rideId);

    if (!this.rideSubscriptions.has(rideId)) {
      this.rideSubscriptions.set(rideId, new Set());
    }
    this.rideSubscriptions.get(rideId).add(ws);
    return true;
  }

  /**
   * Unsubscribes a connection from a ride.
   */
  unsubscribeFromRide(ws, rideId) {
    const info = this.connections.get(ws);
    if (info) {
      info.subscriptions.delete(rideId);
    }

    if (this.rideSubscriptions.has(rideId)) {
      this.rideSubscriptions.get(rideId).delete(ws);
      if (this.rideSubscriptions.get(rideId).size === 0) {
        this.rideSubscriptions.delete(rideId);
      }
    }
  }

  /**
   * Unregisters and cleans up a disconnected connection.
   */
  unregister(ws) {
    const info = this.connections.get(ws);
    if (!info) return;

    // Clean up ride subscriptions
    for (const rideId of info.subscriptions) {
      if (this.rideSubscriptions.has(rideId)) {
        this.rideSubscriptions.get(rideId).delete(ws);
        if (this.rideSubscriptions.get(rideId).size === 0) {
          this.rideSubscriptions.delete(rideId);
        }
      }
    }

    // Clean up user connections
    if (info.uid && this.userConnections.has(info.uid)) {
      const set = this.userConnections.get(info.uid);
      set.delete(ws);
      if (set.size === 0) {
        this.userConnections.delete(info.uid);
        if (info.role === 'driver') {
          this.setDriverOffline(info.uid);
        }
      }
    }

    this.connections.delete(ws);
  }

  /**
   * Sends a structured JSON message to a single WebSocket.
   */
  send(ws, message) {
    if (ws && ws.readyState === 1 /* OPEN */) {
      try {
        const payload = typeof message === 'string' ? message : JSON.stringify(message);
        ws.send(payload);
        return true;
      } catch (err) {
        console.error('[ConnectionManager] Send error:', err.message);
        return false;
      }
    }
    return false;
  }

  /**
   * Sends a message to all active connections for a given user UID.
   */
  sendToUser(uid, message) {
    const sockets = this.userConnections.get(uid);
    if (!sockets || sockets.size === 0) return 0;

    let count = 0;
    for (const ws of sockets) {
      if (this.send(ws, message)) {
        count++;
      }
    }
    return count;
  }

  /**
   * Broadcasts a message to all authorized subscribers of a ride.
   */
  sendToRideSubscribers(rideId, message, excludeWs = null) {
    const sockets = this.rideSubscriptions.get(rideId);
    if (!sockets || sockets.size === 0) return 0;

    let count = 0;
    for (const ws of sockets) {
      if (ws !== excludeWs) {
        if (this.send(ws, message)) {
          count++;
        }
      }
    }
    return count;
  }

  /**
   * Broadcasts a ride request to all online drivers matching a predicate.
   */
  sendToOnlineDrivers(message, filterFn = null) {
    let count = 0;
    for (const [uid] of this.onlineDrivers) {
      if (!filterFn || filterFn(uid)) {
        count += this.sendToUser(uid, message);
      }
    }
    return count;
  }

  /**
   * Returns connection info for a WebSocket.
   */
  getInfo(ws) {
    return this.connections.get(ws);
  }

  /**
   * Total active connections.
   */
  get activeCount() {
    return this.connections.size;
  }
}

module.exports = ConnectionManager;
