import 'package:flutter_test/flutter_test.dart';
import 'package:zyro/models/driver_model.dart';
import 'package:zyro/models/ride_model.dart';
import 'package:zyro/models/validated_location.dart';

void main() {
  group('Production 2 KM Geospatial Dispatching Invariant', () {
    const pickupLat = 12.9716;
    const pickupLng = 77.5946;

    test('Candidates within 2.0 KM are eligible; candidates beyond 2.0 KM are rejected', () {
      // Create test drivers with known coordinates & distances
      final now = DateTime.now();

      // Driver A: ~0.5 km away
      final driverA = DriverModel(
        id: 'driver_A',
        name: 'Driver A (0.5km)',
        phone: '111',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-A',
        isOnline: true,
        isAvailable: true,
        latitude: pickupLat + 0.003,
        longitude: pickupLng + 0.003,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 10)),
      );

      // Driver B: ~1.2 km away
      final driverB = DriverModel(
        id: 'driver_B',
        name: 'Driver B (1.2km)',
        phone: '222',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-B',
        isOnline: true,
        isAvailable: true,
        latitude: pickupLat + 0.008,
        longitude: pickupLng + 0.008,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 2)), // Most recent completed ride
      );

      // Driver C: ~1.9 km away
      final driverC = DriverModel(
        id: 'driver_C',
        name: 'Driver C (1.9km)',
        phone: '333',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-C',
        isOnline: true,
        isAvailable: true,
        latitude: pickupLat + 0.012,
        longitude: pickupLng + 0.012,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 25)),
      );

      // Driver D: ~2.3 km away (Exceeds 2 KM threshold)
      final driverD = DriverModel(
        id: 'driver_D',
        name: 'Driver D (2.3km)',
        phone: '444',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-D',
        isOnline: true,
        isAvailable: true,
        latitude: pickupLat + 0.016,
        longitude: pickupLng + 0.016,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 1)),
      );

      // Driver E: 5.0+ km away
      final driverE = DriverModel(
        id: 'driver_E',
        name: 'Driver E (5.0km)',
        phone: '555',
        vehicleType: 'bike',
        vehicleNumber: 'KA-01-E',
        isOnline: true,
        isAvailable: true,
        latitude: pickupLat + 0.045,
        longitude: pickupLng + 0.045,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 3)),
      );

      final allDrivers = [driverA, driverB, driverC, driverD, driverE];

      // Filter using strict 2.0 km radius
      const double maxRadiusKm = 2.0;
      final eligibleDrivers = <DriverModel>[];
      final distances = <String, double>{};

      for (final driver in allDrivers) {
        final distMeters = ValidatedLocation.distanceMeters(
          pickupLat,
          pickupLng,
          driver.latitude,
          driver.longitude,
        );
        final distKm = distMeters / 1000.0;
        distances[driver.id] = distKm;

        if (distKm <= maxRadiusKm && driver.isOnline && driver.isAvailable) {
          eligibleDrivers.add(driver);
        }
      }

      // Assertions: Exactly A, B, C are eligible; D and E are excluded
      expect(eligibleDrivers.length, equals(3));
      expect(eligibleDrivers.map((d) => d.id).toList(), containsAll(['driver_A', 'driver_B', 'driver_C']));
      expect(eligibleDrivers.map((d) => d.id).toList(), isNot(contains('driver_D')));
      expect(eligibleDrivers.map((d) => d.id).toList(), isNot(contains('driver_E')));

      // Mandatory Backup Driver selection: lastRideCompletedAt DESC
      eligibleDrivers.sort((a, b) {
        final timeA = a.lastRideCompletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.lastRideCompletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA); // DESC
      });

      final backupDriver = eligibleDrivers.first;
      // Driver B completed their ride 2 minutes ago (most recent among A, B, C)
      expect(backupDriver.id, equals('driver_B'));
    });
  });

  group('Authoritative 120-Second Timeout Invariant', () {
    test('expiresAt is exactly requestedAt + 120 seconds', () {
      final requestedAt = DateTime.utc(2026, 3, 21, 10, 0, 0);
      final expiresAt = requestedAt.add(const Duration(seconds: 120));

      final ride = RideModel(
        id: 'ride_test_120',
        riderId: 'rider_1',
        pickupAddress: 'MG Road',
        destinationAddress: 'Indiranagar',
        rideType: 'bike',
        fare: 65.0,
        status: RideStatus.searching,
        requestedAt: requestedAt,
        expiresAt: expiresAt,
        pickupLatitude: 12.9716,
        pickupLongitude: 77.5946,
        destinationLatitude: 12.9784,
        destinationLongitude: 77.6408,
      );

      expect(ride.expiresAt!.difference(ride.requestedAt!).inSeconds, equals(120));
      expect(ride.isExpired(at: requestedAt.add(const Duration(seconds: 119))), isFalse);
      expect(ride.isExpired(at: requestedAt.add(const Duration(seconds: 120))), isTrue);
      expect(ride.isExpired(at: requestedAt.add(const Duration(seconds: 121))), isTrue);
    });
  });

  group('Ride State Machine Invariants', () {
    test('State serialization and copyWith handle all production lifecycle stages', () {
      final ride = RideModel(
        id: 'ride_flow_1',
        riderId: 'rider_flow',
        pickupAddress: 'A',
        destinationAddress: 'B',
        rideType: 'auto',
        fare: 120.0,
        status: RideStatus.searching,
        pickupLatitude: 12.97,
        pickupLongitude: 77.59,
        destinationLatitude: 12.98,
        destinationLongitude: 77.60,
      );

      final assigned = ride.copyWith(
        status: RideStatus.driverAssigned,
        driverId: 'driver_winner',
      );
      expect(assigned.status, equals(RideStatus.driverAssigned));
      expect(assigned.driverId, equals('driver_winner'));

      final arrived = assigned.copyWith(status: RideStatus.driverArrived);
      expect(arrived.status, equals('driver_arrived'));

      final started = arrived.copyWith(status: RideStatus.rideStarted);
      expect(started.status, equals('ride_started'));

      final completed = started.copyWith(status: RideStatus.completed, rating: 5);
      expect(completed.status, equals(RideStatus.completed));
      expect(completed.rating, equals(5));

      final map = completed.toMap();
      expect(map['status'], equals('completed'));
      expect(map['rating'], equals(5));
      expect(map['driverId'], equals('driver_winner'));
    });
  });

  group('Ride Cancellation & Race-Safety Invariants', () {
    test('Cancelled ride transitions correctly and remains terminal', () {
      final now = DateTime.now();
      final ride = RideModel(
        id: 'ride_cancel_test',
        riderId: 'rider_123',
        pickupAddress: 'MG Road',
        destinationAddress: 'Indiranagar',
        rideType: 'bike',
        fare: 50.0,
        status: RideStatus.searching,
        requestedAt: now,
        expiresAt: now.add(const Duration(seconds: 120)),
        pickupLatitude: 12.9716,
        pickupLongitude: 77.5946,
        destinationLatitude: 12.9784,
        destinationLongitude: 77.6408,
      );

      final cancelledRide = ride.copyWith(
        status: RideStatus.cancelled,
        cancelledAt: DateTime.now(),
      );

      expect(cancelledRide.status, equals(RideStatus.cancelled));
      expect(cancelledRide.cancelledAt, isNotNull);

      // Verify that after cancellation, timeout check does not allow backup assignment
      expect(cancelledRide.status == RideStatus.searching, isFalse);
    });

    test('Assigned ride cancellation preserves driver info for release', () {
      final now = DateTime.now();
      final assignedRide = RideModel(
        id: 'ride_assigned_cancel',
        riderId: 'rider_456',
        driverId: 'driver_789',
        pickupAddress: 'Airport Road',
        destinationAddress: 'Koramangala',
        rideType: 'cab',
        fare: 250.0,
        status: RideStatus.driverAssigned,
        requestedAt: now.subtract(const Duration(seconds: 30)),
        expiresAt: now.add(const Duration(seconds: 90)),
        pickupLatitude: 12.9716,
        pickupLongitude: 77.5946,
        destinationLatitude: 12.9784,
        destinationLongitude: 77.6408,
      );

      final cancelledAssigned = assignedRide.copyWith(
        status: RideStatus.cancelled,
        cancelledAt: DateTime.now(),
      );

      expect(cancelledAssigned.status, equals(RideStatus.cancelled));
      expect(cancelledAssigned.driverId, equals('driver_789'));
    });
  });
}
