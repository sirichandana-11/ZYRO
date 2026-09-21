const admin = require('firebase-admin');

class LocationManager {
  constructor(connectionManager, options = {}) {
    this.connectionManager = connectionManager;
    // Configurable location update throttling in milliseconds
    this.updateIntervalMs = options.updateIntervalMs || parseInt(process.env.LOCATION_UPDATE_INTERVAL_MS, 10) || 2500;
    this.minDistanceMeters = options.minDistanceMeters || parseInt(process.env.LOCATION_MIN_DISTANCE_METERS, 10) || 10;
    // driverId -> { lastUpdate: number, latitude: number, longitude: number, accuracy: number, activeRideId: string|null }
    this.driverLocations = new Map();
    // driverId -> activeRideId cache to optimize lookup speed
    this.driverActiveRides = new Map();
  }

  /**
   * Approximate distance in meters between two lat/lng pairs.
   */
  static getDistanceMeters(lat1, lon1, lat2, lon2) {
    const dLat = (lat2 - lat1) * (Math.PI / 180.0);
    const dLon = (lon2 - lon1) * (Math.PI / 180.0);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * (Math.PI / 180.0)) *
        Math.cos(lat2 * (Math.PI / 180.0)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return 6371000.0 * c;
  }

  /**
   * Validates geographical coordinate numbers.
   */
  static isValidCoordinate(latitude, longitude) {
    if (typeof latitude !== 'number' || typeof longitude !== 'number') return false;
    if (isNaN(latitude) || isNaN(longitude)) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude === 0 && longitude === 0) return false; // null-island check
    return true;
  }

  /**
   * Sets or caches the active ride ID for an assigned driver.
   */
  setDriverActiveRide(driverId, rideId) {
    if (!driverId) return;
    if (rideId) {
      this.driverActiveRides.set(driverId, rideId);
    } else {
      this.driverActiveRides.delete(driverId);
    }
  }

  /**
   * Looks up the active ride ID for a driver from cache or Firestore.
   */
  async getDriverActiveRide(driverId) {
    if (this.driverActiveRides.has(driverId)) {
      return this.driverActiveRides.get(driverId);
    }

    try {
      if (admin.apps.length > 0) {
        const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
        if (driverDoc.exists && driverDoc.data() && driverDoc.data().activeRideId) {
          const activeRideId = driverDoc.data().activeRideId;
          this.driverActiveRides.set(driverId, activeRideId);
          return activeRideId;
        }
      }
    } catch (err) {
      console.warn(`[LocationManager] Could not fetch active ride for driver ${driverId}: ${err.message}`);
    }

    return null;
  }

  /**
   * Processes an incoming driver_location event.
   *
   * @param {Object} ws - The sender WebSocket.
   * @param {Object} connectionInfo - Server-verified connection metadata.
   * @param {Object} payload - { latitude, longitude, accuracy, rideId }
   * @returns {Promise<boolean>}
   */
  async handleDriverLocation(ws, connectionInfo, payload) {
    if (!connectionInfo || !connectionInfo.isAuthenticated) {
      this.connectionManager.send(ws, {
        type: 'error',
        payload: { message: 'Must be authenticated to send location.' },
      });
      return false;
    }

    if (connectionInfo.role !== 'driver') {
      this.connectionManager.send(ws, {
        type: 'error',
        payload: { message: 'Only driver accounts may emit driver_location events.' },
      });
      return false;
    }

    const { latitude, longitude, accuracy, rideId } = payload || {};

    if (!LocationManager.isValidCoordinate(latitude, longitude)) {
      this.connectionManager.send(ws, {
        type: 'error',
        payload: { message: `Invalid coordinates: lat=${latitude}, lng=${longitude}` },
      });
      return false;
    }

    const driverId = connectionInfo.uid;
    const now = Date.now();

    // Check throttle (time + displacement)
    const last = this.driverLocations.get(driverId);
    if (last) {
      const timeDeltaMs = now - last.lastUpdate;
      const distanceMeters = LocationManager.getDistanceMeters(last.latitude, last.longitude, latitude, longitude);

      if (timeDeltaMs < this.updateIntervalMs && distanceMeters < this.minDistanceMeters) {
        // Throttled: update internal coordinates without broadcasting redundant frame
        last.latitude = latitude;
        last.longitude = longitude;
        last.accuracy = accuracy || last.accuracy;
        return true;
      }
    }

    // Cache latest location
    this.driverLocations.set(driverId, {
      lastUpdate: now,
      latitude,
      longitude,
      accuracy: accuracy || 10.0,
    });

    // Determine target active ride
    const targetRideId = rideId || (await this.getDriverActiveRide(driverId));
    if (targetRideId) {
      this.setDriverActiveRide(driverId, targetRideId);
    }

    const locationMessage = {
      type: 'driver_location',
      timestamp: now,
      payload: {
        driverId,
        latitude,
        longitude,
        accuracy: accuracy || 10.0,
        rideId: targetRideId || null,
      },
    };

    // SECURITY: Route ONLY to authorized subscribers of the active ride
    if (targetRideId) {
      const deliveredCount = this.connectionManager.sendToRideSubscribers(targetRideId, locationMessage, ws);
      return deliveredCount > 0;
    }

    return true;
  }
}

module.exports = LocationManager;
