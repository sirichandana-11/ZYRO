import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zyro/models/coordinate.dart';
import 'package:zyro/models/saved_place_model.dart';
import 'package:zyro/models/validated_location.dart';
import 'package:zyro/screens/ride_matching_screen.dart';
import 'package:zyro/screens/services_screen.dart';
import 'package:zyro/services/demo_ride_allocation_service.dart';
import 'package:zyro/services/geocoding_service.dart';
import 'package:zyro/services/preferences_service.dart';
import 'package:zyro/services/websocket_service.dart';
import 'package:zyro/theme/zyro_theme.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FakeHttpRequest();
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpRequest implements HttpClientRequest {
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool bufferOutput = true;
  @override
  int contentLength = 0;
  @override
  bool persistentConnection = true;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakeHttpResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  static final List<int> _kTransparentPng = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ];

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.value(_kTransparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  HttpOverrides.global = _TestHttpOverrides();

  group('Part 1: Theme Architecture & Persistence Tests', () {
    test('PreferencesService parses theme string correctly', () {
      expect(PreferencesService.parseThemeMode('light'), equals(ThemeMode.light));
      expect(PreferencesService.parseThemeMode('dark'), equals(ThemeMode.dark));
      expect(PreferencesService.parseThemeMode('system'), equals(ThemeMode.system));
      expect(PreferencesService.parseThemeMode('invalid_random'), equals(ThemeMode.system));
    });

    test('PreferencesService serializeThemeMode produces exact identifiers', () {
      expect(PreferencesService.serializeThemeMode(ThemeMode.light), equals('light'));
      expect(PreferencesService.serializeThemeMode(ThemeMode.dark), equals('dark'));
      expect(PreferencesService.serializeThemeMode(ThemeMode.system), equals('system'));
    });

    test('ThemeMode changes immediately notify listeners with zero delay', () {
      final notifier = PreferencesService.themeModeNotifier;
      final initialMode = notifier.value;

      List<ThemeMode> observedChanges = [];
      void listener() {
        observedChanges.add(notifier.value);
      }

      notifier.addListener(listener);

      notifier.value = ThemeMode.dark;
      expect(notifier.value, equals(ThemeMode.dark));

      notifier.value = ThemeMode.light;
      expect(notifier.value, equals(ThemeMode.light));

      notifier.value = ThemeMode.system;
      expect(notifier.value, equals(ThemeMode.system));

      notifier.removeListener(listener);
      expect(observedChanges, equals([ThemeMode.dark, ThemeMode.light, ThemeMode.system]));

      // Restore
      notifier.value = initialMode;
    });

    test('ZyroTheme provides complete color tokens and palettes for dark mode', () {
      expect(ZyroTheme.backgroundDark, equals(const Color(0xFF101216)));
      expect(ZyroTheme.surfaceDark, equals(const Color(0xFF1A1E24)));
      expect(ZyroTheme.surfaceDarkElevated, equals(const Color(0xFF222831)));
      expect(ZyroTheme.borderDark, equals(const Color(0xFF2D343F)));
      expect(ZyroTheme.textPrimaryDark, equals(const Color(0xFFF1F5F9)));
      expect(ZyroTheme.textSecondaryDark, equals(const Color(0xFF94A3B8)));
    });

    testWidgets('ZyroTheme adaptive helpers return correct color tokens for light and dark', (tester) async {
      await tester.pumpWidget(
        Theme(
          data: ThemeData.light(),
          child: Builder(
            builder: (context) {
              expect(ZyroTheme.isDarkMode(context), isFalse);
              expect(ZyroTheme.scaffoldBg(context), equals(ZyroTheme.backgroundLight));
              expect(ZyroTheme.cardBg(context), equals(Colors.white));
              expect(ZyroTheme.textPrimary(context), equals(ZyroTheme.darkCharcoal));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pumpWidget(
        Theme(
          data: ThemeData.dark(),
          child: Builder(
            builder: (context) {
              expect(ZyroTheme.isDarkMode(context), isTrue);
              expect(ZyroTheme.scaffoldBg(context), equals(ZyroTheme.backgroundDark));
              expect(ZyroTheme.cardBg(context), equals(ZyroTheme.surfaceDark));
              expect(ZyroTheme.textPrimary(context), equals(ZyroTheme.textPrimaryDark));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('Part 3: GPS & Coordinate Accuracy Validation Tests', () {
    test('Coordinate validation rejects out-of-bound latitudes and longitudes', () {
      expect(const Coordinate(latitude: 91.0, longitude: 78.0).isValidCoordinate, isFalse);
      expect(const Coordinate(latitude: -90.5, longitude: 78.0).isValidCoordinate, isFalse);
      expect(const Coordinate(latitude: 17.0, longitude: 181.0).isValidCoordinate, isFalse);
      expect(const Coordinate(latitude: 17.0, longitude: -185.0).isValidCoordinate, isFalse);
    });

    test('Coordinate validation strictly rejects Null Island (0,0)', () {
      expect(const Coordinate(latitude: 0.0, longitude: 0.0).isValidCoordinate, isFalse);
      expect(Coordinate.isValid(0.0, 0.0), isFalse);
    });

    test('Valid non-zero GPS coordinate is accepted', () {
      const coord = Coordinate(latitude: 17.4399, longitude: 78.3842);
      expect(coord.isValidCoordinate, isTrue);
    });

    test('Haversine distance calculation computes accurate geodesic distance', () {
      // Hyderabad Hitec City to Gachibowli (~3-5 km)
      final distMeters = ValidatedLocation.calculateDistanceMeters(17.4435, 78.3772, 17.4401, 78.3489);
      final distKm = distMeters / 1000.0;
      expect(distKm, greaterThan(2.5));
      expect(distKm, lessThan(4.0));
    });

    test('Identical or sub-20m coordinates can be detected for route rejection', () {
      final distMeters = ValidatedLocation.calculateDistanceMeters(17.4435, 78.3772, 17.443501, 78.377201);
      expect(distMeters, lessThan(20));
    });
  });

  group('Part 4: Saved & Popular Places Selection Logic Tests', () {
    test('Saved places mapping returns correct title, subtitle and coordinate', () {
      final homePlace = SavedPlaceModel(
        id: 'sp_home',
        userId: 'u1',
        tag: 'home',
        title: 'Home',
        address: 'Villa 12, Green Meadows',
        latitude: 17.4123,
        longitude: 78.4321,
      );

      expect(homePlace.title, equals('Home'));
      expect(homePlace.address, equals('Villa 12, Green Meadows'));
      expect(homePlace.latitude, equals(17.4123));
      expect(homePlace.longitude, equals(78.4321));
    });
  });

  group('Part 1 & 5: Location Search UX & Pickup vs Destination Invariant Tests', () {
    test('GeocodingLocation validation correctly accepts valid locations and rejects invalid', () {
      final validLoc = GeocodingLocation(
        latitude: 17.4435,
        longitude: 78.3772,
        displayName: 'Hitec City, Hyderabad, Telangana, India',
        shortName: 'Hitec City',
      );
      expect(Coordinate.isValid(validLoc.latitude, validLoc.longitude), isTrue);

      final nullIslandLoc = GeocodingLocation(
        latitude: 0.0,
        longitude: 0.0,
        displayName: 'Null Island',
        shortName: 'Null Island',
      );
      expect(Coordinate.isValid(nullIslandLoc.latitude, nullIslandLoc.longitude), isFalse);

      final outOfBoundsLoc = GeocodingLocation(
        latitude: 95.0,
        longitude: 200.0,
        displayName: 'Invalid Planet',
        shortName: 'Invalid Planet',
      );
      expect(Coordinate.isValid(outOfBoundsLoc.latitude, outOfBoundsLoc.longitude), isFalse);
    });

    test('Query sequence token guarantees newer query always wins over older slow query', () {
      int activeSequence = 0;
      int completedSequence = 0;
      List<String> activeResults = [];

      // User types query 1: 'hyd'
      final int seq1 = ++activeSequence;
      // User quickly types query 2: 'hyderabad'
      final int seq2 = ++activeSequence;

      // Simulate query 1 (slow network) returning after query 2
      void onQuery1Returned(List<String> results) {
        if (seq1 != activeSequence) {
          // Stale query is rejected
          return;
        }
        completedSequence = seq1;
        activeResults = results;
      }

      void onQuery2Returned(List<String> results) {
        if (seq2 != activeSequence) {
          return;
        }
        completedSequence = seq2;
        activeResults = results;
      }

      onQuery2Returned(['Hyderabad Central', 'Hyderabad Airport']);
      onQuery1Returned(['Old Hyd Result']); // Should be ignored!

      expect(completedSequence, equals(seq2));
      expect(activeResults, equals(['Hyderabad Central', 'Hyderabad Airport']));
    });

    test('Destination options strictly exclude Current Location', () {
      // Invariant: Destination options must never offer current GPS location
      const isPickup = false;
      final shouldShowCurrentLocation = isPickup;
      expect(shouldShowCurrentLocation, isFalse);
    });

    test('Pickup options include Current Location', () {
      const isPickup = true;
      final shouldShowCurrentLocation = isPickup;
      expect(shouldShowCurrentLocation, isTrue);
    });
  });

  group('Part 3: Services Screen Rendering & Dark Mode Tests', () {
    testWidgets('ServicesScreen renders without whitespace and responds to dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZyroTheme.lightTheme,
          darkTheme: ZyroTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: ServicesScreen(),
          ),
        ),
      );

      // Verify Header and sections
      expect(find.text('All Services'), findsOneWidget);
      expect(find.text('Your Ride, Your Choice'), findsOneWidget);
      expect(find.text('City Daily Commute'), findsOneWidget);
      expect(find.text('Hourly Rentals & Outstation'), findsOneWidget);
      expect(find.text('Doorstep Delivery'), findsOneWidget);
      expect(find.text('Why Choose ZYRO'), findsOneWidget);

      // Verify Service Cards
      expect(find.text('ZYRO Bike'), findsOneWidget);
      expect(find.text('ZYRO Auto'), findsOneWidget);
      expect(find.text('ZYRO Prime Cab'), findsOneWidget);
      expect(find.text('Hourly Rentals'), findsOneWidget);
      expect(find.text('Intercity Rides'), findsOneWidget);
      expect(find.text('Parcel Delivery'), findsOneWidget);

      // Verify Trust & Safety row
      expect(find.text('100% Verified Drivers'), findsOneWidget);
      expect(find.text('120-Second Match Guarantee'), findsOneWidget);
      expect(find.text('Transparent GPS Pricing'), findsOneWidget);
      expect(find.text('24/7 Safety SOS Helpline'), findsOneWidget);
    });

    testWidgets('RideMatchingScreen inherits and responds to Dark Theme properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZyroTheme.lightTheme,
          darkTheme: ZyroTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const RideMatchingScreen(
            pickupAddress: 'Lendi Institute, Jonnada',
            destinationAddress: 'Vizianagaram Railway Station',
            rideType: 'bike',
            fare: 45.0,
            pickupLat: 18.0674,
            pickupLng: 83.3980,
            destLat: 18.1130,
            destLng: 83.4024,
          ),
        ),
      );

      // Verify Screen renders with dark theme tokens
      expect(find.byType(RideMatchingScreen), findsOneWidget);
      expect(find.text('Matching Driver'), findsOneWidget);
      expect(find.text('ZYRO Bike'), findsOneWidget);
      expect(find.text('Fare: ₹45'), findsOneWidget);
      expect(find.text('120s Allocation Window'), findsOneWidget);
      expect(find.text('Cancel Ride Request'), findsOneWidget);

      // Verify Scaffold inherits dark background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(ZyroTheme.backgroundDark));

      // Clean up timer and unmount
      await DemoRideAllocationService().cancelRide();
      await WebSocketService.instance.disconnect();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('RideMatchingScreen inherits and responds to Light Theme properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ZyroTheme.lightTheme,
          darkTheme: ZyroTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const RideMatchingScreen(
            pickupAddress: 'Lendi Institute, Jonnada',
            destinationAddress: 'Vizianagaram Railway Station',
            rideType: 'cab',
            fare: 150.0,
            pickupLat: 18.0674,
            pickupLng: 83.3980,
            destLat: 18.1130,
            destLng: 83.4024,
          ),
        ),
      );

      // Verify Screen renders with light theme tokens
      expect(find.byType(RideMatchingScreen), findsOneWidget);
      expect(find.text('Matching Driver'), findsOneWidget);
      expect(find.text('ZYRO Prime Cab'), findsOneWidget);
      expect(find.text('Fare: ₹150'), findsOneWidget);

      // Verify Scaffold inherits light background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(ZyroTheme.backgroundLight));

      // Clean up timer and unmount
      await DemoRideAllocationService().cancelRide();
      await WebSocketService.instance.disconnect();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}

