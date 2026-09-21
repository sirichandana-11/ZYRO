/**
 * ZYRO Geospatial Driver Matching Service
 * 
 * Partitions driver search using spatial bounding grids, filters candidates
 * by availability and telemetry freshness, and selects the mandatory backup driver.
 */

const EARTH_RADIUS_KM = 6371.0;

class GeospatialMatchingService {
  /**
   * Calculates great-circle distance between two points in kilometers (Haversine formula).
   */
  static calculateDistanceKm(lat1, lon1, lat2, lon2) {
    const dLat = this.toRadians(lat2 - lat1);
    const dLon = this.toRadians(lon2 - lon1);

    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRadians(lat1)) *
        Math.cos(this.toRadians(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return EARTH_RADIUS_KM * c;
  }

  static toRadians(degree) {
    return degree * (Math.PI / 180.0);
  }

  /**
   * Generates a spatial bounding box for candidate filtering.
   * Approx 1 deg lat = 111 km, 1 deg lon = 111 * cos(lat) km.
   */
  static getBoundingBox(centerLat, centerLng, radiusKm = 10.0) {
    const latDelta = radiusKm / 111.0;
    const lonDelta = radiusKm / (111.0 * Math.cos(this.toRadians(centerLat)));

    return {
      minLat: centerLat - latDelta,
      maxLat: centerLat + latDelta,
      minLng: centerLng - lonDelta,
      maxLng: centerLng + lonDelta,
    };
  }

  /**
   * Computes a spatial cell key for spatial partitioning (approx 1.5km x 1.5km grid).
   */
  static getSpatialCellKey(lat, lng, precision = 2) {
    const latBucket = (Math.floor(lat * Math.pow(10, precision)) / Math.pow(10, precision)).toFixed(precision);
    const lngBucket = (Math.floor(lng * Math.pow(10, precision)) / Math.pow(10, precision)).toFixed(precision);
    return `cell_${latBucket}_${lngBucket}`;
  }

  /**
   * Finds eligible drivers within geographic radius and applies strict operational filters:
   * 1. Spatial bounding box & distance threshold
   * 2. Online and available status
   * 3. Vehicle type match
   * 4. Location freshness threshold (rejects drivers with stale telemetry > 30s)
   */
  static findEligibleDrivers({
    drivers = [],
    pickupLat,
    pickupLng,
    rideType,
    maxRadiusKm = 10.0,
    maxLocationAgeSeconds = 30,
  }) {
    if (!drivers || drivers.length === 0) return [];

    const now = Date.now();
    const bbox = this.getBoundingBox(pickupLat, pickupLng, maxRadiusKm);
    const eligible = [];

    for (const driver of drivers) {
      // 1. Basic status filters
      if (!driver.isOnline || !driver.isAvailable) continue;

      // 2. Vehicle type filter (case-insensitive)
      if (driver.vehicleType && driver.vehicleType.toLowerCase() !== rideType.toLowerCase()) {
        continue;
      }

      // 3. Location freshness check
      if (driver.lastLocationAt) {
        const lastLocTime = driver.lastLocationAt instanceof Date
          ? driver.lastLocationAt.getTime()
          : new Date(driver.lastLocationAt).getTime();
        const ageSec = (now - lastLocTime) / 1000;
        if (ageSec > maxLocationAgeSeconds) {
          // Stale telemetry - exclude from matching pool
          continue;
        }
      }

      // 4. Quick bounding box check
      if (
        driver.latitude < bbox.minLat ||
        driver.latitude > bbox.maxLat ||
        driver.longitude < bbox.minLng ||
        driver.longitude > bbox.maxLng
      ) {
        continue;
      }

      // 5. Exact Haversine distance calculation
      const distanceKm = this.calculateDistanceKm(
        pickupLat,
        pickupLng,
        driver.latitude,
        driver.longitude
      );

      if (distanceKm <= maxRadiusKm) {
        eligible.push({
          ...driver,
          distanceKm: parseFloat(distanceKm.toFixed(2)),
        });
      }
    }

    // Sort by distance ascending as standard ranking
    eligible.sort((a, b) => a.distanceKm - b.distanceKm);

    return eligible;
  }

  /**
   * Selects exactly ONE deterministic mandatory backup driver.
   * Business Rules:
   * 1. Most recently completed previous ride (lastRideCompletedAt descending).
   * 2. Fallback: nearest distance to pickup.
   * 3. Fallback: alphabetical driver ID.
   */
  static selectMandatoryBackupDriver(eligibleDrivers) {
    if (!eligibleDrivers || eligibleDrivers.length === 0) return null;

    const candidates = [...eligibleDrivers];

    candidates.sort((a, b) => {
      const timeA = a.lastRideCompletedAt ? new Date(a.lastRideCompletedAt).getTime() : 0;
      const timeB = b.lastRideCompletedAt ? new Date(b.lastRideCompletedAt).getTime() : 0;

      // Rule 1: Most recent completed trip
      if (timeA !== timeB) {
        return timeB - timeA; // Descending
      }

      // Rule 2: Nearest distance
      if (a.distanceKm !== b.distanceKm) {
        return a.distanceKm - b.distanceKm; // Ascending
      }

      // Rule 3: Deterministic tiebreaker
      return (a.id || '').localeCompare(b.id || '');
    });

    return candidates[0];
  }
}

module.exports = {
  GeospatialMatchingService,
};
