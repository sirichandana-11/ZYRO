const functions = require('./index.js');
console.log('Exported functions:', Object.keys(functions));
const { haversineDistanceKm } = require('./utils/geo');
const DriverService = require('./services/driverService');

// Test Haversine formula
const dist = haversineDistanceKm(12.9716, 77.5946, 12.9352, 77.6245);
console.log('Sample distance calculation (Bangalore):', dist.toFixed(2), 'km');

// Test DriverService backup selection logic
const ds = new DriverService(null);
const testDrivers = [
  { id: 'driver_1', name: 'Alice', lastRideCompletedAt: new Date(Date.now() - 3600000), distanceKm: 2.1 },
  { id: 'driver_2', name: 'Bob', lastRideCompletedAt: new Date(Date.now() - 600000), distanceKm: 3.5 }, // More recent ride
  { id: 'driver_3', name: 'Charlie', lastRideCompletedAt: null, distanceKm: 1.0 }
];

const backup = ds.selectBackupDriver(testDrivers);
console.log('Selected backup driver (should be driver_2):', backup.id);

if (backup.id === 'driver_2') {
  console.log('ALL SYNTAX & LOGIC TESTS PASSED!');
} else {
  throw new Error('Backup driver selection failed test');
}
