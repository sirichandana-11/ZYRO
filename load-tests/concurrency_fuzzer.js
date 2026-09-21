/**
 * ZYRO Concurrency Fuzzer: Atomic Acceptance Race-Condition Test
 * 
 * Simulates N concurrent drivers attempting to accept the exact same ride
 * at the same millisecond.
 * 
 * Verifies Invariants:
 * 1. Exactly ONE driver wins assignment (First-Driver-Wins).
 * 2. N - 1 drivers are safely rejected with 'already_assigned' or 'invalid_status'.
 * 3. Ride status is DRIVER_ASSIGNED with the single winning driverId.
 * 4. Zero double-booking or corrupt state.
 */

const assert = require('assert');
const { RideStatus, RideStateMachine } = require('../backend/src/services/ride_state_machine');

class MockAtomicFirestore {
  constructor() {
    this.rides = new Map();
    this.drivers = new Map();
  }

  setRide(rideId, data) {
    this.rides.set(rideId, { ...data });
  }

  // Simulates an atomic Firestore runTransaction with isolation lock
  async runTransaction(updateFn) {
    // In memory atomic execution
    const snapshot = {
      get: (collection, id) => {
        if (collection === 'rides') return this.rides.get(id);
        if (collection === 'drivers') return this.drivers.get(id);
        return null;
      },
      update: (collection, id, patch) => {
        if (collection === 'rides') {
          const r = this.rides.get(id) || {};
          this.rides.set(id, { ...r, ...patch });
        }
      },
    };

    return await updateFn(snapshot);
  }

  async acceptRideTransaction(rideId, driverId) {
    return await this.runTransaction(async (tx) => {
      const ride = tx.get('rides', rideId);
      if (!ride) {
        return { success: false, reason: 'ride_not_found' };
      }

      if (ride.status !== RideStatus.SEARCHING) {
        return { success: false, reason: 'ride_already_assigned_or_inactive', currentStatus: ride.status };
      }

      if (ride.driverId) {
        return { success: false, reason: 'driver_already_assigned', assignedDriver: ride.driverId };
      }

      // Transition state
      RideStateMachine.transition(ride, RideStatus.DRIVER_ASSIGNED, {
        actorUid: driverId,
        actorRole: 'driver',
        reason: 'concurrency_atomic_acceptance',
      });

      ride.driverId = driverId;
      tx.update('rides', rideId, ride);

      return {
        success: true,
        rideId,
        driverId,
      };
    });
  }
}

async function runConcurrencyFuzzTest(driverCount = 100) {
  console.log(`=== Running Concurrency Fuzzing: ${driverCount} Simultaneous Driver Acceptances ===`);

  const db = new MockAtomicFirestore();
  const rideId = 'ride_fuzz_target_999';

  db.setRide(rideId, {
    id: rideId,
    riderId: 'rider_test_01',
    status: RideStatus.SEARCHING,
    driverId: null,
    pickupLatitude: 18.0674,
    pickupLongitude: 83.3980,
    requestedAt: new Date(),
    auditTrail: [],
  });

  const drivers = Array.from({ length: driverCount }, (_, i) => `drv_fuzz_${i.toString().padStart(3, '0')}`);

  // Shuffle drivers array to simulate arbitrary arrival times
  const shuffled = [...drivers].sort(() => Math.random() - 0.5);

  const startTime = Date.now();

  // Fire all N requests concurrently using Promise.all
  const results = await Promise.all(
    shuffled.map((driverId) => db.acceptRideTransaction(rideId, driverId))
  );

  const durationMs = Date.now() - startTime;

  const successful = results.filter((r) => r.success === true);
  const rejected = results.filter((r) => r.success === false);

  console.log(`[Summary] Total Attempts: ${results.length}`);
  console.log(`[Summary] Success Count:  ${successful.length} (Expected: 1)`);
  console.log(`[Summary] Rejected Count: ${rejected.length} (Expected: ${driverCount - 1})`);
  console.log(`[Summary] Fuzzing Duration: ${durationMs}ms`);

  // Assertions
  assert.strictEqual(successful.length, 1, 'Invariant Violation: Exactly ONE driver must win.');
  assert.strictEqual(rejected.length, driverCount - 1, `Invariant Violation: Exactly ${driverCount - 1} drivers must be rejected.`);

  const winner = successful[0];
  const finalRide = db.rides.get(rideId);

  assert.strictEqual(finalRide.status, RideStatus.DRIVER_ASSIGNED);
  assert.strictEqual(finalRide.driverId, winner.driverId);
  assert.strictEqual(finalRide.auditTrail.length, 1);

  console.log(`[PASS] Invariant Verified! Winning Driver: ${winner.driverId}`);
  console.log('------------------------------------------------');
}

runConcurrencyFuzzTest(100);
