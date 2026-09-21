/**
 * ZYRO Backend Domain Services Test Suite
 */

const assert = require('assert');
const { RideStatus, RideStateMachine, InvalidStateTransitionError } = require('../src/services/ride_state_machine');
const { GeospatialMatchingService } = require('../src/services/geospatial_matching');
const { IdempotencyManager } = require('../src/services/idempotency_manager');
const { TimeoutScheduler } = require('../src/jobs/timeout_scheduler');
const { InMemoryPubSubAdapter } = require('../../websocket-server/pubsub_adapter');

let passed = 0;
let failed = 0;

function it(desc, fn) {
  try {
    fn();
    console.log(`[PASS] ${desc}`);
    passed++;
  } catch (err) {
    console.error(`[FAIL] ${desc}:`, err.message);
    failed++;
  }
}

async function itAsync(desc, fn) {
  try {
    await fn();
    console.log(`[PASS] ${desc}`);
    passed++;
  } catch (err) {
    console.error(`[FAIL] ${desc}:`, err.message);
    failed++;
  }
}

async function runTests() {
  console.log('--- Running ZYRO Backend Domain Services Unit Tests ---');

  // --- 1. Ride State Machine Tests ---
  it('RideStateMachine permits valid sequential transitions', () => {
    const ride = { id: 'ride_001', status: RideStatus.CREATED };

    RideStateMachine.transition(ride, RideStatus.SEARCHING, { actorUid: 'rider_1', actorRole: 'rider' });
    assert.strictEqual(ride.status, RideStatus.SEARCHING);
    assert.strictEqual(ride.auditTrail.length, 1);

    RideStateMachine.transition(ride, RideStatus.DRIVER_ASSIGNED, { actorUid: 'drv_1', actorRole: 'driver' });
    assert.strictEqual(ride.status, RideStatus.DRIVER_ASSIGNED);
    assert.ok(ride.assignedAt);

    RideStateMachine.transition(ride, RideStatus.DRIVER_ARRIVING, { actorUid: 'drv_1', actorRole: 'driver' });
    assert.strictEqual(ride.status, RideStatus.DRIVER_ARRIVING);

    RideStateMachine.transition(ride, RideStatus.RIDE_STARTED, { actorUid: 'drv_1', actorRole: 'driver' });
    assert.strictEqual(ride.status, RideStatus.RIDE_STARTED);
    assert.ok(ride.startedAt);

    RideStateMachine.transition(ride, RideStatus.COMPLETED, { actorUid: 'drv_1', actorRole: 'driver' });
    assert.strictEqual(ride.status, RideStatus.COMPLETED);
    assert.ok(ride.completedAt);
    assert.strictEqual(ride.auditTrail.length, 5);
  });

  it('RideStateMachine rejects invalid transitions and terminal mutations', () => {
    const ride = { id: 'ride_002', status: RideStatus.COMPLETED };

    assert.throws(() => {
      RideStateMachine.transition(ride, RideStatus.SEARCHING);
    }, InvalidStateTransitionError);

    const cancelledRide = { id: 'ride_003', status: RideStatus.CANCELLED };
    assert.throws(() => {
      RideStateMachine.transition(cancelledRide, RideStatus.DRIVER_ASSIGNED);
    }, InvalidStateTransitionError);
  });

  it('RideStateMachine handles idempotent duplicate state transitions', () => {
    const ride = { id: 'ride_004', status: RideStatus.SEARCHING, auditTrail: [] };
    const res = RideStateMachine.transition(ride, RideStatus.SEARCHING);
    assert.strictEqual(res.changed, false);
    assert.strictEqual(ride.auditTrail.length, 0);
  });

  // --- 2. Geospatial Matching Tests ---
  it('GeospatialMatchingService calculates accurate distances', () => {
    // Distance between Bengaluru (12.9716, 77.5946) and Koramangala (12.9352, 77.6245) is ~5.2 km
    const dist = GeospatialMatchingService.calculateDistanceKm(12.9716, 77.5946, 12.9352, 77.6245);
    assert.ok(dist > 4.5 && dist < 6.0, `Calculated distance ${dist}km should be approx 5.2km`);
  });

  it('GeospatialMatchingService filters candidates by vehicle, status, and freshness', () => {
    const now = Date.now();
    const drivers = [
      {
        id: 'd1_valid',
        name: 'Driver 1',
        isOnline: true,
        isAvailable: true,
        vehicleType: 'bike',
        latitude: 18.0680,
        longitude: 83.3990,
        lastLocationAt: new Date(now - 5000), // 5s ago (fresh)
        lastRideCompletedAt: new Date(now - 600000),
      },
      {
        id: 'd2_stale',
        name: 'Driver 2',
        isOnline: true,
        isAvailable: true,
        vehicleType: 'bike',
        latitude: 18.0682,
        longitude: 83.3992,
        lastLocationAt: new Date(now - 120000), // 120s ago (>30s stale)
      },
      {
        id: 'd3_busy',
        name: 'Driver 3',
        isOnline: true,
        isAvailable: false, // Busy
        vehicleType: 'bike',
        latitude: 18.0680,
        longitude: 83.3990,
      },
      {
        id: 'd4_wrong_vehicle',
        name: 'Driver 4',
        isOnline: true,
        isAvailable: true,
        vehicleType: 'auto', // Not bike
        latitude: 18.0680,
        longitude: 83.3990,
      },
    ];

    const eligible = GeospatialMatchingService.findEligibleDrivers({
      drivers,
      pickupLat: 18.0674,
      pickupLng: 83.3980,
      rideType: 'bike',
      maxRadiusKm: 5.0,
      maxLocationAgeSeconds: 30,
    });

    assert.strictEqual(eligible.length, 1);
    assert.strictEqual(eligible[0].id, 'd1_valid');
  });

  it('GeospatialMatchingService selects deterministic mandatory backup driver by most recent completed trip', () => {
    const now = Date.now();
    const candidates = [
      {
        id: 'd_older',
        distanceKm: 0.5,
        lastRideCompletedAt: new Date(now - 3600000), // 1 hour ago
      },
      {
        id: 'd_recent_winner',
        distanceKm: 1.2,
        lastRideCompletedAt: new Date(now - 300000), // 5 mins ago (winner)
      },
      {
        id: 'd_no_prev_ride',
        distanceKm: 0.3,
        lastRideCompletedAt: null,
      },
    ];

    const backup = GeospatialMatchingService.selectMandatoryBackupDriver(candidates);
    assert.strictEqual(backup.id, 'd_recent_winner');
  });

  // --- 3. Idempotency Manager Tests ---
  await itAsync('IdempotencyManager prevents duplicate executions', async () => {
    const mgr = new IdempotencyManager(5000);
    let executionCount = 0;

    const action = async () => {
      executionCount++;
      return { rideId: 'ride_idemp_100', status: 'SEARCHING' };
    };

    const res1 = await mgr.executeIdempotent('create_ride', 'key_abc', action);
    assert.strictEqual(res1.isIdempotentReplay, false);
    assert.strictEqual(executionCount, 1);

    const res2 = await mgr.executeIdempotent('create_ride', 'key_abc', action);
    assert.strictEqual(res2.isIdempotentReplay, true);
    assert.strictEqual(executionCount, 1); // Not called again!
  });

  // --- 4. Timeout Scheduler Tests ---
  await itAsync('TimeoutScheduler cancels cleanly on early acceptance', async () => {
    const scheduler = new TimeoutScheduler();
    let expired = false;

    scheduler.scheduleAllocationTimeout('ride_test_timeout', {
      durationMs: 500,
      onExpire: () => { expired = true; },
    });

    assert.strictEqual(scheduler.hasActiveTimeout('ride_test_timeout'), true);
    const cancelled = scheduler.cancelAllocationTimeout('ride_test_timeout');
    assert.strictEqual(cancelled, true);

    // Wait past timeout
    await new Promise((r) => setTimeout(r, 600));
    assert.strictEqual(expired, false, 'Expired callback should not have fired after cancellation');
  });

  // --- 5. PubSub Adapter Tests ---
  await itAsync('InMemoryPubSubAdapter delivers messages to channel subscribers', async () => {
    const pubsub = new InMemoryPubSubAdapter();
    const received = [];

    const handler = (msg) => {
      received.push(JSON.parse(msg));
    };

    await pubsub.subscribe('ride_updates:ride_777', handler);
    await pubsub.publish('ride_updates:ride_777', { event: 'driver_assigned', driverId: 'drv_9' });

    assert.strictEqual(received.length, 1);
    assert.strictEqual(received[0].driverId, 'drv_9');

    await pubsub.unsubscribe('ride_updates:ride_777', handler);
    await pubsub.publish('ride_updates:ride_777', { event: 'ignored' });
    assert.strictEqual(received.length, 1);
  });

  console.log('------------------------------------------------');
  console.log(`Test Results: ${passed} passed, ${failed} failed`);
  console.log('------------------------------------------------');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
