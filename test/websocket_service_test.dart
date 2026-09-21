import 'package:flutter_test/flutter_test.dart';
import 'package:zyro/services/websocket_service.dart';

void main() {
  group('WebSocket Event Models Test', () {
    test('DriverLocationEvent deserializes correctly', () {
      final json = {
        'driverId': 'drv_test_01',
        'latitude': 18.0674,
        'longitude': 83.3980,
        'accuracy': 5.2,
        'speed': 12.5,
        'heading': 180.0,
        'rideId': 'ride_123',
      };

      final event = DriverLocationEvent.fromJson(json);
      expect(event.driverId, 'drv_test_01');
      expect(event.latitude, 18.0674);
      expect(event.longitude, 83.3980);
      expect(event.accuracy, 5.2);
      expect(event.speed, 12.5);
      expect(event.heading, 180.0);
      expect(event.rideId, 'ride_123');
    });

    test('RideRequestEvent deserializes correctly', () {
      final exp = DateTime.now().add(const Duration(seconds: 120));
      final json = {
        'rideId': 'ride_abc_999',
        'pickupLatitude': 18.0674,
        'pickupLongitude': 83.3980,
        'destinationLatitude': 18.1100,
        'destinationLongitude': 83.4100,
        'rideType': 'bike',
        'fare': 45.0,
        'expiresAt': exp.millisecondsSinceEpoch,
      };

      final event = RideRequestEvent.fromJson(json);
      expect(event.rideId, 'ride_abc_999');
      expect(event.pickupLatitude, 18.0674);
      expect(event.pickupLongitude, 83.3980);
      expect(event.fare, 45.0);
      expect(event.rideType, 'bike');
      expect(event.expiresAt, isNotNull);
    });

    test('RideAssignedEvent deserializes correctly', () {
      final json = {
        'rideId': 'ride_999',
        'driverId': 'drv_winner',
        'driverName': 'Rajesh Kumar',
        'driverPhone': '+91 98765 43210',
        'vehicleNumber': 'ZYRO-101',
        'vehicleType': 'bike',
        'latitude': 18.0680,
        'longitude': 83.3990,
      };

      final event = RideAssignedEvent.fromJson(json);
      expect(event.rideId, 'ride_999');
      expect(event.driverId, 'drv_winner');
      expect(event.driverName, 'Rajesh Kumar');
      expect(event.vehicleNumber, 'ZYRO-101');
      expect(event.latitude, 18.0680);
      expect(event.longitude, 83.3990);
    });

    test('WebSocketConfig respects custom URL override', () {
      WebSocketConfig.customServerUrl = 'ws://192.168.1.50:8080';
      expect(WebSocketConfig.defaultUrl, 'ws://192.168.1.50:8080');
      WebSocketConfig.customServerUrl = null;
    });

    test('WebSocketService instance is singleton', () {
      final s1 = WebSocketService();
      final s2 = WebSocketService.instance;
      expect(identical(s1, s2), isTrue);
      expect(s1.status, WebSocketConnectionStatus.disconnected);
    });
  });
}
