import 'package:flutter_test/flutter_test.dart';
import 'package:zyro/models/payment_method_model.dart';
import 'package:zyro/models/saved_place_model.dart';
import 'package:zyro/services/preferences_service.dart';

void main() {
  group('SavedPlaceModel Tests', () {
    test('SavedPlaceModel serialization and deserialization works correctly', () {
      final now = DateTime.now();
      final place = SavedPlaceModel(
        id: 'place_123',
        userId: 'user_456',
        tag: 'home',
        title: 'Home',
        address: 'Plot 42, Jubilee Hills, Hyderabad',
        latitude: 17.4319,
        longitude: 78.4073,
        createdAt: now,
      );

      final map = place.toMap();
      expect(map['title'], equals('Home'));
      expect(map['address'], equals('Plot 42, Jubilee Hills, Hyderabad'));
      expect(map['latitude'], equals(17.4319));
      expect(map['longitude'], equals(78.4073));
      expect(map['tag'], equals('home'));
      expect(map['userId'], equals('user_456'));

      final reconstructed = SavedPlaceModel.fromMap(map, id: 'place_123');
      expect(reconstructed.id, equals('place_123'));
      expect(reconstructed.userId, equals('user_456'));
      expect(reconstructed.title, equals('Home'));
      expect(reconstructed.address, equals('Plot 42, Jubilee Hills, Hyderabad'));
      expect(reconstructed.latitude, equals(17.4319));
      expect(reconstructed.longitude, equals(78.4073));
      expect(reconstructed.tag, equals('home'));
    });

    test('SavedPlaceModel handles different place tags accurately', () {
      final workPlace = SavedPlaceModel(
        id: 'p_work',
        userId: 'user_1',
        tag: 'work',
        title: 'Tech Park',
        address: 'Hitec City, Hyderabad',
        latitude: 17.4435,
        longitude: 78.3772,
      );
      expect(workPlace.tag, equals('work'));

      final otherPlace = SavedPlaceModel(
        id: 'p_gym',
        userId: 'user_1',
        tag: 'other',
        title: 'Fitness Hub',
        address: 'Madhapur, Hyderabad',
        latitude: 17.4483,
        longitude: 78.3915,
      );
      expect(otherPlace.tag, equals('other'));
    });

    test('SavedPlaceModel copyWith updates fields immutably', () {
      final original = SavedPlaceModel(
        id: 'p_1',
        userId: 'u_1',
        tag: 'other',
        title: 'Old Title',
        address: 'Old Address',
        latitude: 12.9716,
        longitude: 77.5946,
      );

      final updated = original.copyWith(
        title: 'New Title',
        address: 'New Address',
        tag: 'home',
      );

      expect(updated.id, equals('p_1'));
      expect(updated.title, equals('New Title'));
      expect(updated.address, equals('New Address'));
      expect(updated.tag, equals('home'));
      expect(updated.latitude, equals(12.9716));
    });
  });

  group('PaymentMethodModel & Security Tests', () {
    test('PaymentMethodModel stores only safe display metadata without sensitive credentials', () {
      final cardMethod = PaymentMethodModel(
        id: 'card_01',
        userId: 'user_1',
        type: 'card',
        displayName: 'HDFC Visa Debit Card',
        last4: '4321',
        isDefault: true,
      );

      final map = cardMethod.toMap();
      expect(map['type'], equals('card'));
      expect(map['last4'], equals('4321'));
      expect(map['displayName'], equals('HDFC Visa Debit Card'));
      expect(map['isDefault'], isTrue);

      // Verify no sensitive fields exist in output map
      expect(map.containsKey('cvv'), isFalse);
      expect(map.containsKey('pin'), isFalse);
      expect(map.containsKey('cardNumber'), isFalse);
      expect(map.containsKey('password'), isFalse);
    });

    test('PaymentMethodModel supports UPI and Cash types', () {
      final upiMethod = PaymentMethodModel(
        id: 'upi_01',
        userId: 'user_1',
        type: 'upi',
        displayName: 'Google Pay UPI',
        upiId: 'rider@okaxis',
        isDefault: true,
      );

      expect(upiMethod.type, equals('upi'));
      expect(upiMethod.upiId, equals('rider@okaxis'));

      final cashMethod = PaymentMethodModel(
        id: 'cash_01',
        userId: 'user_1',
        type: 'cash',
        displayName: 'Cash',
        isDefault: false,
      );

      expect(cashMethod.type, equals('cash'));
      expect(cashMethod.displayName, equals('Cash'));
    });

    test('PaymentMethodModel correctly reconstructs from Firestore map', () {
      final rawMap = {
        'userId': 'user_99',
        'type': 'card',
        'displayName': 'ICICI Platinum Credit',
        'last4': '9876',
        'isDefault': false,
      };

      final method = PaymentMethodModel.fromMap(rawMap, id: 'card_99');
      expect(method.id, equals('card_99'));
      expect(method.userId, equals('user_99'));
      expect(method.type, equals('card'));
      expect(method.displayName, equals('ICICI Platinum Credit'));
      expect(method.last4, equals('9876'));
      expect(method.isDefault, isFalse);
    });
  });

  group('Preferences Defaults & Mapping Tests', () {
    test('PreferencesService provides complete default notification preferences', () {
      final service = PreferencesService();
      // Stream for empty string UID emits default safe preferences
      expect(
        service.watchNotificationPreferences(''),
        emits(predicate<Map<String, bool>>((prefs) {
          return prefs['driverAssigned'] == true &&
              prefs['driverArriving'] == true &&
              prefs['rideStarted'] == true &&
              prefs['rideCompleted'] == true &&
              prefs['rideCancelled'] == true &&
              prefs['promotions'] == false &&
              prefs['securityAlerts'] == true;
        })),
      );
    });

    test('PreferencesService provides standard default app preferences', () {
      final service = PreferencesService();
      expect(
        service.watchAppPreferences(''),
        emits(predicate<Map<String, dynamic>>((prefs) {
          return prefs['themeMode'] == 'system' &&
              prefs['distanceUnit'] == 'km' &&
              prefs['mapStyle'] == 'standard';
        })),
      );
    });
  });
}
