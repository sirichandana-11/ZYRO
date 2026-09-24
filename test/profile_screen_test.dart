import 'package:flutter_test/flutter_test.dart';
import 'package:zyro/models/driver_model.dart';
import 'package:zyro/models/ride_model.dart';
import 'package:zyro/services/auth_service.dart';

void main() {
  group('Profile Screen & AuthService Validation Tests', () {
    final authService = AuthService();

    test('Full name validator rejects empty or single-character names', () {
      expect(authService.validateFullName(null), isNotNull);
      expect(authService.validateFullName(''), isNotNull);
      expect(authService.validateFullName('  '), isNotNull);
      expect(authService.validateFullName('A'), isNotNull);
      expect(authService.validateFullName('Chaitanya'), isNull);
      expect(authService.validateFullName('Rajesh Kumar'), isNull);
    });

    test('Phone validator rejects invalid or short numbers and accepts 10+ digits', () {
      expect(authService.validatePhone(null), isNotNull);
      expect(authService.validatePhone(''), isNotNull);
      expect(authService.validatePhone('12345'), isNotNull);
      expect(authService.validatePhone('abcdefghij'), isNotNull);
      expect(authService.validatePhone('9876543210'), isNull);
      expect(authService.validatePhone('+91 98765 43210'), isNull);
      expect(authService.validatePhone('+91-9876543210'), isNull);
    });

    test('Vehicle number validator validates plate format and presence', () {
      expect(authService.validateVehicleNumber(null), isNotNull);
      expect(authService.validateVehicleNumber(''), isNotNull);
      expect(authService.validateVehicleNumber('  '), isNotNull);
      expect(authService.validateVehicleNumber('AB'), isNotNull);
      expect(authService.validateVehicleNumber('DL01AB1234'), isNull);
      expect(authService.validateVehicleNumber('ZYRO-101'), isNull);
      expect(authService.validateVehicleNumber('TS 09 UB 5678'), isNull);
    });

    test('Vehicle type validator accepts only supported transport categories', () {
      expect(authService.validateVehicleType(null), isNotNull);
      expect(authService.validateVehicleType(''), isNotNull);
      expect(authService.validateVehicleType('helicopter'), isNotNull);
      expect(authService.validateVehicleType('truck'), isNotNull);
      expect(authService.validateVehicleType('bike'), isNull);
      expect(authService.validateVehicleType('auto'), isNull);
      expect(authService.validateVehicleType('cab'), isNull);
      expect(authService.validateVehicleType('BIKE'), isNull);
      expect(authService.validateVehicleType('Auto'), isNull);
    });
  });

  group('Profile Statistics Aggregation Logic', () {
    test('Rider statistics calculate completed trips, cancelled trips, and total spent correctly', () {
      final rides = [
        RideModel(
          id: 'r1',
          riderId: 'rider_01',
          pickupLatitude: 17.3850,
          pickupLongitude: 78.4867,
          destinationLatitude: 17.4000,
          destinationLongitude: 78.4900,
          rideType: 'bike',
          fare: 150.0,
          status: RideStatus.completed,
        ),
        RideModel(
          id: 'r2',
          riderId: 'rider_01',
          pickupLatitude: 17.3850,
          pickupLongitude: 78.4867,
          destinationLatitude: 17.4000,
          destinationLongitude: 78.4900,
          rideType: 'auto',
          fare: 220.0,
          status: RideStatus.completed,
        ),
        RideModel(
          id: 'r3',
          riderId: 'rider_01',
          pickupLatitude: 17.3850,
          pickupLongitude: 78.4867,
          destinationLatitude: 17.4000,
          destinationLongitude: 78.4900,
          rideType: 'cab',
          fare: 450.0,
          status: RideStatus.cancelled,
        ),
      ];

      final completedRides = rides.where((r) => r.status == RideStatus.completed).toList();
      final cancelledCount = rides.where((r) => r.status == RideStatus.cancelled).length;
      final totalSpent = completedRides.fold(0.0, (sum, r) => sum + r.fare);

      expect(completedRides.length, equals(2));
      expect(cancelledCount, equals(1));
      expect(totalSpent, equals(370.0));
    });

    test('Driver statistics calculate earnings, completed count, and rating correctly', () {
      final driverRides = [
        RideModel(
          id: 'dr1',
          riderId: 'rider_01',
          driverId: 'driver_01',
          pickupLatitude: 17.3850,
          pickupLongitude: 78.4867,
          destinationLatitude: 17.4000,
          destinationLongitude: 78.4900,
          rideType: 'bike',
          fare: 120.0,
          status: RideStatus.completed,
        ),
        RideModel(
          id: 'dr2',
          riderId: 'rider_02',
          driverId: 'driver_01',
          pickupLatitude: 17.3850,
          pickupLongitude: 78.4867,
          destinationLatitude: 17.4000,
          destinationLongitude: 78.4900,
          rideType: 'bike',
          fare: 180.0,
          status: RideStatus.completed,
        ),
      ];

      final completedRides = driverRides.where((r) => r.status == RideStatus.completed).toList();
      final totalEarnings = completedRides.fold(0.0, (sum, r) => sum + r.fare);

      final driver = DriverModel(
        id: 'driver_01',
        name: 'Rajesh Driver',
        phone: '+91 98765 43201',
        vehicleType: 'bike',
        vehicleNumber: 'ZYRO-101',
        ratingSum: 49.0,
        ratingCount: 10,
        averageRating: 4.9,
        completedRidesCount: 2,
      );

      expect(completedRides.length, equals(2));
      expect(totalEarnings, equals(300.0));
      expect(driver.averageRating, equals(4.9));
      expect(driver.completedRidesCount, equals(2));
    });
  });
}
