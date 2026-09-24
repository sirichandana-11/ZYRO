const admin = require('firebase-admin');

class RideEventManager {
  constructor(connectionManager) {
    this.connectionManager = connectionManager;
    // rideId -> { riderId: string, driverId: string|null, eligibleDriverIds: string[], status: string }
    this.rideMetadataCache = new Map();
  }

  /**
   * Caches ride authorization metadata.
   */
  setRideMetadata(rideId, metadata) {
    if (!rideId) return;
    this.rideMetadataCache.set(rideId, metadata);
  }

  /**
   * Fetches ride authorization metadata from cache or Firestore.
   */
  async getRideMetadata(rideId) {
    if (this.rideMetadataCache.has(rideId)) {
      return this.rideMetadataCache.get(rideId);
    }

    try {
      if (admin.apps.length > 0) {
        const doc = await admin.firestore().collection('rides').doc(rideId).get();
        if (doc.exists && doc.data()) {
          const data = doc.data();
          const meta = {
            riderId: data.riderId,
            driverId: data.driverId || null,
            eligibleDriverIds: Array.isArray(data.eligibleDriverIds) ? data.eligibleDriverIds : [],
            status: data.status || 'searching',
          };
          this.rideMetadataCache.set(rideId, meta);
          return meta;
        }
      }
    } catch (err) {
      console.warn(`[RideEvents] Could not fetch ride metadata for ${rideId}: ${err.message}`);
    }

    return null;
  }

  /**
   * Authorizes and handles a client's subscribe_ride request.
   */
  async handleSubscribeRide(ws, connectionInfo, payload) {
    if (!connectionInfo || !connectionInfo.isAuthenticated) {
      this.connectionManager.send(ws, {
        type: 'error',
        payload: { message: 'Must be authenticated to subscribe to ride events.' },
      });
      return false;
    }

    const { rideId } = payload || {};
    if (!rideId || typeof rideId !== 'string') {
      this.connectionManager.send(ws, {
        type: 'error',
        payload: { message: 'A valid rideId string is required to subscribe.' },
      });
      return false;
    }

    const uid = connectionInfo.uid;
    const meta = await this.getRideMetadata(rideId);

    // If metadata found, strictly authorize:
    if (meta) {
      const isRider = meta.riderId === uid;
      const isAssignedDriver = meta.driverId === uid;
      const isEligibleDriver = meta.eligibleDriverIds.includes(uid);

      if (!isRider && !isAssignedDriver && !isEligibleDriver) {
        this.connectionManager.send(ws, {
          type: 'error',
          payload: { message: `Unauthorized: User ${uid} is not associated with ride ${rideId}.` },
        });
        return false;
      }
    }

    this.connectionManager.subscribeToRide(ws, rideId);
    this.connectionManager.send(ws, {
      type: 'subscribed_ride',
      payload: { rideId },
    });
    return true;
  }

  /**
   * Handles a client's unsubscribe_ride request.
   */
  handleUnsubscribeRide(ws, connectionInfo, payload) {
    const { rideId } = payload || {};
    if (rideId) {
      this.connectionManager.unsubscribeFromRide(ws, rideId);
      this.connectionManager.send(ws, {
        type: 'unsubscribed_ride',
        payload: { rideId },
      });
    }
  }

  /**
   * Broadcasts a ride_request event to eligible online drivers.
   */
  broadcastRideRequest(rideData) {
    const { rideId, pickupLatitude, pickupLongitude, destinationLatitude, destinationLongitude, rideType, fare, expiresAt, eligibleDriverIds } = rideData;

    const message = {
      type: 'ride_request',
      timestamp: Date.now(),
      payload: {
        rideId,
        pickupLatitude,
        pickupLongitude,
        destinationLatitude,
        destinationLongitude,
        rideType: rideType || 'bike',
        fare: fare || 49.0,
        expiresAt: expiresAt || Date.now() + 120000,
      },
    };

    // Cache metadata for subsequent subscriptions
    this.setRideMetadata(rideId, {
      riderId: rideData.riderId,
      driverId: null,
      eligibleDriverIds: Array.isArray(eligibleDriverIds) ? eligibleDriverIds : [],
      status: 'searching',
    });

    if (Array.isArray(eligibleDriverIds) && eligibleDriverIds.length > 0) {
      let count = 0;
      for (const driverId of eligibleDriverIds) {
        count += this.connectionManager.sendToUser(driverId, message);
      }
      return count;
    } else {
      return this.connectionManager.sendToOnlineDrivers(message);
    }
  }

  /**
   * Emits a ride_assigned event to all subscribers of the ride.
   */
  notifyRideAssigned(rideId, assignedData) {
    const meta = this.rideMetadataCache.get(rideId) || {};
    meta.driverId = assignedData.driverId;
    meta.status = 'driver_assigned';
    this.setRideMetadata(rideId, meta);

    const message = {
      type: 'ride_assigned',
      timestamp: Date.now(),
      payload: {
        rideId,
        driverId: assignedData.driverId,
        driverName: assignedData.driverName || 'Assigned Driver',
        driverPhone: assignedData.driverPhone,
        vehicleNumber: assignedData.vehicleNumber,
        vehicleType: assignedData.vehicleType,
      },
    };

    return this.connectionManager.sendToRideSubscribers(rideId, message);
  }

  /**
   * Emits a ride_status_changed event to all subscribers of the ride.
   */
  notifyRideStatusChanged(rideId, status, extra = {}) {
    const meta = this.rideMetadataCache.get(rideId) || {};
    meta.status = status;
    this.setRideMetadata(rideId, meta);

    const message = {
      type: 'ride_status_changed',
      timestamp: Date.now(),
      payload: {
        rideId,
        status,
        ...extra,
      },
    };

    return this.connectionManager.sendToRideSubscribers(rideId, message);
  }

  /**
   * Emits a ride_cancelled event to all subscribers of the ride and offered drivers.
   */
  notifyRideCancelled(rideId, cancelData = {}) {
    const meta = this.rideMetadataCache.get(rideId) || {};
    meta.status = 'cancelled';
    this.setRideMetadata(rideId, meta);

    const message = {
      type: 'ride_cancelled',
      timestamp: Date.now(),
      payload: {
        rideId,
        reason: cancelData.reason || 'Rider cancelled request',
      },
    };

    // 1. Notify ride subscribers (e.g. rider, assigned driver)
    this.connectionManager.sendToRideSubscribers(rideId, message);

    // 2. Also notify candidate drivers who were offered the ride
    if (Array.isArray(meta.eligibleDriverIds)) {
      for (const driverId of meta.eligibleDriverIds) {
        this.connectionManager.sendToUser(driverId, message);
      }
    }

    return true;
  }
}

module.exports = RideEventManager;
