import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_model.dart';

/// Service managing driver records and real-time state in Cloud Firestore.
class DriverService {
  static final DriverService _instance = DriverService._internal();
  factory DriverService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return DriverService._withFirestore(firestore);
    }
    return _instance;
  }
  DriverService._internal() : _customFirestore = null;
  DriverService._withFirestore(this._customFirestore);

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _driversCollection =>
      _firestore.collection('drivers');

  /// Creates or updates a driver record in Firestore (`drivers/{driver.id}`).
  Future<void> createOrUpdateDriver(DriverModel driver) async {
    final data = driver.toMap();
    await _driversCollection.doc(driver.id).set(
          data,
          SetOptions(merge: true),
        );
  }

  /// Fetches a driver document once by ID.
  Future<DriverModel?> getDriver(String driverId) async {
    if (driverId.isEmpty) return null;
    final doc = await _driversCollection.doc(driverId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DriverModel.fromFirestore(doc);
  }

  /// Listens to a driver document in real time.
  Stream<DriverModel?> watchDriver(String driverId) {
    if (driverId.isEmpty) {
      return Stream.value(null);
    }
    return _driversCollection.doc(driverId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return DriverModel.fromFirestore(snapshot);
    });
  }

  /// Listens to all active and available drivers in real time.
  Stream<List<DriverModel>> watchAvailableDrivers({String? vehicleType}) {
    Query<Map<String, dynamic>> query = _driversCollection
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true);

    if (vehicleType != null && vehicleType.isNotEmpty) {
      query = query.where('vehicleType', isEqualTo: vehicleType);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => DriverModel.fromFirestore(doc)).toList();
    });
  }

  /// Updates driver GPS coordinates in Firestore.
  Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    if (driverId.isEmpty) return;
    await _driversCollection.doc(driverId).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Sets driver online/offline status and resets availability accordingly.
  Future<void> setDriverOnline({
    required String driverId,
    required bool isOnline,
    double? latitude,
    double? longitude,
  }) async {
    if (driverId.isEmpty) return;

    final updateData = <String, dynamic>{
      'isOnline': isOnline,
      'isAvailable': isOnline,
    };

    if (latitude != null && longitude != null) {
      updateData['latitude'] = latitude;
      updateData['longitude'] = longitude;
    }

    // If going offline, clear active ride
    if (!isOnline) {
      updateData['activeRideId'] = null;
    }

    await _driversCollection.doc(driverId).set(
          updateData,
          SetOptions(merge: true),
        );
  }

  /// Sets driver availability (e.g. available vs busy on ride).
  Future<void> setDriverAvailability({
    required String driverId,
    required bool isAvailable,
  }) async {
    if (driverId.isEmpty) return;
    await _driversCollection.doc(driverId).update({
      'isAvailable': isAvailable,
    });
  }

  /// Sets or clears the active ride on the driver document.
  Future<void> setActiveRide({
    required String driverId,
    String? rideId,
  }) async {
    if (driverId.isEmpty) return;
    await _driversCollection.doc(driverId).update({
      'activeRideId': rideId,
      'isAvailable': rideId == null,
    });
  }

  /// Marks a ride as completed for the driver and updates `lastRideCompletedAt`.
  Future<void> completeRide({required String driverId}) async {
    if (driverId.isEmpty) return;
    await _driversCollection.doc(driverId).update({
      'activeRideId': null,
      'isAvailable': true,
      'lastRideCompletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Initializes standard presentation demo drivers in Firestore.
  ///
  /// Initializes standard presentation demo drivers in Firestore around the user's real GPS position.
  Future<void> initializeDemoDrivers({
    required double centerLat,
    required double centerLng,
  }) async {
    final now = DateTime.now();

    final demoDrivers = [
      DriverModel(
        id: 'demo_driver_01',
        name: 'ZYRO Driver 01 (Rajesh)',
        phone: '+91 98765 43201',
        vehicleType: 'bike',
        vehicleNumber: 'ZYRO-101',
        isOnline: true,
        isAvailable: true,
        latitude: centerLat + 0.0035,
        longitude: centerLng + 0.0025,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 5)),
      ),
      DriverModel(
        id: 'demo_driver_02',
        name: 'ZYRO Driver 02 (Suresh)',
        phone: '+91 98765 43202',
        vehicleType: 'bike',
        vehicleNumber: 'ZYRO-102',
        isOnline: true,
        isAvailable: true,
        latitude: centerLat - 0.0048,
        longitude: centerLng + 0.0038,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 18)),
      ),
      DriverModel(
        id: 'demo_driver_03',
        name: 'ZYRO Driver 03 (Ramesh)',
        phone: '+91 98765 43203',
        vehicleType: 'auto',
        vehicleNumber: 'ZYRO-201',
        isOnline: true,
        isAvailable: true,
        latitude: centerLat + 0.0042,
        longitude: centerLng - 0.0032,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 4)),
      ),
      DriverModel(
        id: 'demo_driver_04',
        name: 'ZYRO Driver 04 (Anand)',
        phone: '+91 98765 43204',
        vehicleType: 'auto',
        vehicleNumber: 'ZYRO-202',
        isOnline: true,
        isAvailable: true,
        latitude: centerLat - 0.0062,
        longitude: centerLng - 0.0045,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 25)),
      ),
      DriverModel(
        id: 'demo_driver_05',
        name: 'ZYRO Driver 05 (Vikram)',
        phone: '+91 98765 43205',
        vehicleType: 'cab',
        vehicleNumber: 'ZYRO-301',
        isOnline: true,
        isAvailable: true,
        latitude: centerLat + 0.0051,
        longitude: centerLng + 0.0040,
        lastRideCompletedAt: now.subtract(const Duration(minutes: 7)),
      ),
    ];

    final batch = _firestore.batch();
    for (final driver in demoDrivers) {
      final ref = _driversCollection.doc(driver.id);
      batch.set(ref, driver.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }
}
