const { haversineDistanceKm } = require('../utils/geo');

/**
 * Service for querying and evaluating driver eligibility and backup selection.
 */
class DriverService {
  constructor(firestore) {
    this.firestore = firestore;
  }

  /**
   * Finds nearby eligible drivers for a ride request.
   *
   * Eligibility Criteria:
   * 1. isOnline === true
   * 2. isAvailable === true
   * 3. vehicleType matches requested rideType
   * 4. valid latitude and longitude
   * 5. Distance <= maxRadiusKm (Strictly 2.0 KM for ZYRO dispatch)
   *
   * @param {Object} params
   * @param {number} params.pickupLatitude
   * @param {number} params.pickupLongitude
   * @param {string} params.rideType
   * @param {number} [params.maxRadiusKm=2.0]
   * @returns {Promise<Array<Object>>} Array of eligible driver objects with distanceKm
   */
  async findEligibleDrivers({
    pickupLatitude,
    pickupLongitude,
    rideType,
    maxRadiusKm = 2.0,
  }) {
    if (
      typeof pickupLatitude !== 'number' ||
      typeof pickupLongitude !== 'number' ||
      isNaN(pickupLatitude) ||
      isNaN(pickupLongitude) ||
      (pickupLatitude === 0 && pickupLongitude === 0)
    ) {
      return [];
    }

    // Query active available drivers matching the ride type
    const querySnapshot = await this.firestore
      .collection('drivers')
      .where('isOnline', '==', true)
      .where('isAvailable', '==', true)
      .where('vehicleType', '==', rideType)
      .get();

    const eligibleDrivers = [];

    querySnapshot.forEach((doc) => {
      const data = doc.data();
      const driverLat = typeof data.latitude === 'number' ? data.latitude : null;
      const driverLng = typeof data.longitude === 'number' ? data.longitude : null;

      if (
        driverLat === null ||
        driverLng === null ||
        isNaN(driverLat) ||
        isNaN(driverLng) ||
        (driverLat === 0 && driverLng === 0)
      ) {
        return;
      }

      const distanceKm = haversineDistanceKm(
        pickupLatitude,
        pickupLongitude,
        driverLat,
        driverLng
      );

      if (distanceKm <= maxRadiusKm) {
        eligibleDrivers.push({
          id: doc.id,
          ...data,
          distanceKm: parseFloat(distanceKm.toFixed(3)),
        });
      }
    });

    return eligibleDrivers;
  }

  /**
   * Selects exactly ONE mandatory backup driver from the list of eligible drivers.
   *
   * Selection Algorithm:
   * 1. Check `lastRideCompletedAt` (most recently completed previous ride, descending).
   * 2. If timestamps are absent or tied, fallback deterministically to nearest distance.
   *
   * @param {Array<Object>} eligibleDrivers
   * @returns {Object|null} Selected backup driver object or null
   */
  selectBackupDriver(eligibleDrivers) {
    if (!eligibleDrivers || eligibleDrivers.length === 0) {
      return null;
    }

    // Clone array before sorting
    const drivers = [...eligibleDrivers];

    drivers.sort((a, b) => {
      const timeA = a.lastRideCompletedAt
        ? typeof a.lastRideCompletedAt.toMillis === 'function'
          ? a.lastRideCompletedAt.toMillis()
          : new Date(a.lastRideCompletedAt).getTime()
        : null;

      const timeB = b.lastRideCompletedAt
        ? typeof b.lastRideCompletedAt.toMillis === 'function'
          ? b.lastRideCompletedAt.toMillis()
          : new Date(b.lastRideCompletedAt).getTime()
        : null;

      // Prioritize drivers with valid lastRideCompletedAt (descending - most recent first)
      if (timeA !== null && timeB !== null) {
        if (timeB !== timeA) {
          return timeB - timeA;
        }
      } else if (timeA !== null && timeB === null) {
        return -1;
      } else if (timeA === null && timeB !== null) {
        return 1;
      }

      // Fallback: nearest eligible driver (ascending distance)
      const distA = typeof a.distanceKm === 'number' ? a.distanceKm : Infinity;
      const distB = typeof b.distanceKm === 'number' ? b.distanceKm : Infinity;
      if (distA !== distB) {
        return distA - distB;
      }

      // Deterministic tie-breaker by ID
      return (a.id || '').localeCompare(b.id || '');
    });

    return drivers[0];
  }
}

module.exports = DriverService;
