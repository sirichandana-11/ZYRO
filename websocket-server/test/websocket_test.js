const assert = require('assert');
const ConnectionManager = require('../connection_manager');
const LocationManager = require('../location_manager');
const RideEventManager = require('../ride_events');
const { verifyAuthToken } = require('../auth');

async function runTests() {
  console.log('--- Running ZYRO WebSocket Server Unit Tests ---');
  let passed = 0;
  let failed = 0;

  function test(name, fn) {
    try {
      fn();
      console.log(`[PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`[FAIL] ${name}:`, err.message);
      failed++;
    }
  }

  async function testAsync(name, fn) {
    try {
      await fn();
      console.log(`[PASS] ${name}`);
      passed++;
    } catch (err) {
      console.error(`[FAIL] ${name}:`, err.message);
      failed++;
    }
  }

  // 1. ConnectionManager registration
  test('ConnectionManager registers raw connection', () => {
    const cm = new ConnectionManager();
    const mockWs = { readyState: 1, send: () => {} };
    const info = cm.register(mockWs);

    assert.ok(info.connectionId);
    assert.strictEqual(info.isAuthenticated, false);
    assert.strictEqual(cm.activeCount, 1);
  });

  // 2. Authentication with mock token
  await testAsync('Auth module verifies mock driver token', async () => {
    const res = await verifyAuthToken('mock_token_drv123:driver');
    assert.strictEqual(res.uid, 'drv123');
    assert.strictEqual(res.role, 'driver');
  });

  await testAsync('Auth module verifies mock rider token', async () => {
    const res = await verifyAuthToken('mock_token_rider456:rider');
    assert.strictEqual(res.uid, 'rider456');
    assert.strictEqual(res.role, 'rider');
  });

  await testAsync('Auth module rejects empty or invalid token', async () => {
    let errorThrown = false;
    try {
      await verifyAuthToken('');
    } catch (e) {
      errorThrown = true;
    }
    assert.ok(errorThrown, 'Empty token must throw an error');
  });

  // 3. LocationManager coordinate validation
  test('LocationManager validates geographic bounds', () => {
    assert.strictEqual(LocationManager.isValidCoordinate(18.0674, 83.3980), true);
    assert.strictEqual(LocationManager.isValidCoordinate(90.0, 180.0), true);
    assert.strictEqual(LocationManager.isValidCoordinate(-90.0, -180.0), true);
    // Invalid
    assert.strictEqual(LocationManager.isValidCoordinate(91.0, 83.0), false);
    assert.strictEqual(LocationManager.isValidCoordinate(18.0, 185.0), false);
    assert.strictEqual(LocationManager.isValidCoordinate(NaN, 83.0), false);
    assert.strictEqual(LocationManager.isValidCoordinate(0.0, 0.0), false); // null-island
  });

  // 4. Role Authorization: Rider cannot send driver location
  await testAsync('LocationManager rejects rider sending driver_location', async () => {
    const cm = new ConnectionManager();
    const lm = new LocationManager(cm, { updateIntervalMs: 0 });

    let sentMessage = null;
    const mockWs = {
      readyState: 1,
      send: (msg) => { sentMessage = JSON.parse(msg); },
    };

    const info = cm.register(mockWs);
    cm.authenticate(mockWs, { uid: 'rider_1', role: 'rider', email: 'r@z.app' });

    const result = await lm.handleDriverLocation(mockWs, info, {
      latitude: 18.0674,
      longitude: 83.3980,
      accuracy: 5.0,
    });

    assert.strictEqual(result, false);
    assert.strictEqual(sentMessage?.type, 'error');
    assert.ok(sentMessage?.payload?.message?.includes('Only driver accounts'));
  });

  // 5. Location Routing to Subscribed Rider
  await testAsync('Driver location routes strictly to subscribed rider on active ride', async () => {
    const cm = new ConnectionManager();
    const lm = new LocationManager(cm, { updateIntervalMs: 0 });
    const rm = new RideEventManager(cm);

    let riderReceived = null;
    const riderWs = {
      readyState: 1,
      send: (msg) => { riderReceived = JSON.parse(msg); },
    };
    const driverWs = {
      readyState: 1,
      send: () => {},
    };

    // Register rider & subscribe to ride_999
    const riderInfo = cm.register(riderWs);
    cm.authenticate(riderWs, { uid: 'rider_abc', role: 'rider' });
    rm.setRideMetadata('ride_999', { riderId: 'rider_abc', driverId: 'driver_xyz', eligibleDriverIds: [], status: 'driver_assigned' });
    await rm.handleSubscribeRide(riderWs, riderInfo, { rideId: 'ride_999' });

    // Register driver
    const driverInfo = cm.register(driverWs);
    cm.authenticate(driverWs, { uid: 'driver_xyz', role: 'driver' });
    lm.setDriverActiveRide('driver_xyz', 'ride_999');

    // Driver sends location
    await lm.handleDriverLocation(driverWs, driverInfo, {
      latitude: 18.0674,
      longitude: 83.3980,
      accuracy: 6.2,
      rideId: 'ride_999',
    });

    assert.ok(riderReceived, 'Rider must receive driver_location frame');
    assert.strictEqual(riderReceived.type, 'driver_location');
    assert.strictEqual(riderReceived.payload.driverId, 'driver_xyz');
    assert.strictEqual(riderReceived.payload.latitude, 18.0674);
    assert.strictEqual(riderReceived.payload.longitude, 83.3980);
  });

  // 6. Multi-device tracking
  test('ConnectionManager tracks multiple devices for single user', () => {
    const cm = new ConnectionManager();
    const ws1 = { readyState: 1, send: () => {} };
    const ws2 = { readyState: 1, send: () => {} };

    cm.register(ws1);
    cm.register(ws2);
    cm.authenticate(ws1, { uid: 'user_multi', role: 'driver' });
    cm.authenticate(ws2, { uid: 'user_multi', role: 'driver' });

    assert.strictEqual(cm.userConnections.get('user_multi').size, 2);

    cm.unregister(ws1);
    assert.strictEqual(cm.userConnections.get('user_multi').size, 1);

    cm.unregister(ws2);
    assert.strictEqual(cm.userConnections.has('user_multi'), false);
  });

  console.log('------------------------------------------------');
  console.log(`Test Results: ${passed} passed, ${failed} failed`);
  console.log('------------------------------------------------');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
