import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/driver_model.dart';
import '../models/ride_model.dart';
import 'driver_service.dart';
import 'ride_service.dart';

/// State of the active demo ride allocation session.
class DemoRideState {
  final RideModel ride;
  final List<DriverModel> eligibleDrivers;
  final Map<String, double> driverDistancesKm;
  final DriverModel? backupDriver;
  final DriverModel? assignedDriver;
  final int remainingSeconds; // 120 -> 0
  final String? assignmentReason; // 'driver_accepted' | 'backup_auto_assigned' | 'no_driver'
  final bool isCompleted;

  const DemoRideState({
    required this.ride,
    required this.eligibleDrivers,
    required this.driverDistancesKm,
    this.backupDriver,
    this.assignedDriver,
    required this.remainingSeconds,
    this.assignmentReason,
    this.isCompleted = false,
  });

  DemoRideState copyWith({
    RideModel? ride,
    List<DriverModel>? eligibleDrivers,
    Map<String, double>? driverDistancesKm,
    DriverModel? backupDriver,
    DriverModel? assignedDriver,
    int? remainingSeconds,
    String? assignmentReason,
    bool? isCompleted,
  }) {
    return DemoRideState(
      ride: ride ?? this.ride,
      eligibleDrivers: eligibleDrivers ?? this.eligibleDrivers,
      driverDistancesKm: driverDistancesKm ?? this.driverDistancesKm,
      backupDriver: backupDriver ?? this.backupDriver,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      assignmentReason: assignmentReason ?? this.assignmentReason,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Service managing the local/demo 120-second ride allocation, Firestore synchronization, and race-safe matching.
class DemoRideAllocationService extends ChangeNotifier {
  static final DemoRideAllocationService _instance =
      DemoRideAllocationService._internal();
  factory DemoRideAllocationService() => _instance;
  DemoRideAllocationService._internal();

  final RideService _rideService = RideService();

  Timer? _countdownTimer;
  StreamSubscription<RideModel?>? _firestoreRideSubscription;
  DemoRideState? _currentState;
  bool _isLockAcquired = false;

  DemoRideState? get state => _currentState;
  bool get hasActiveAllocation =>
      _currentState != null && !_currentState!.isCompleted;

  /// Haversine distance calculator in kilometers.
  static double calculateDistanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);

  /// Generates a realistic mock pool of nearby drivers relative to pickup location.
  List<DriverModel> generateMockDrivers({
    required double pickupLat,
    required double pickupLng,
    required String rideType,
  }) {
    final now = DateTime.now();

    // Curate candidate drivers for the ride type
    final List<Map<String, dynamic>> driverConfigs;

    if (rideType == 'bike') {
      driverConfigs = [
        {
          'id': 'demo_driver_01',
          'name': 'ZYRO Driver 01 (Rajesh)',
          'phone': '+91 98765 43201',
          'vehicleType': 'bike',
          'vehicleNumber': 'ZYRO-101',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': 0.0035,
          'lngOffset': 0.0028,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 6)),
        },
        {
          'id': 'demo_driver_02',
          'name': 'ZYRO Driver 02 (Suresh)',
          'phone': '+91 98765 43202',
          'vehicleType': 'bike',
          'vehicleNumber': 'ZYRO-102',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': -0.0052,
          'lngOffset': 0.0041,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 18)),
        },
        {
          'id': 'demo_driver_03',
          'name': 'ZYRO Driver 03 (Manoj)',
          'phone': '+91 98765 43203',
          'vehicleType': 'bike',
          'vehicleNumber': 'ZYRO-103',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': 0.0081,
          'lngOffset': -0.0063,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 42)),
        },
      ];
    } else if (rideType == 'auto') {
      driverConfigs = [
        {
          'id': 'demo_driver_03',
          'name': 'ZYRO Driver 03 (Ramesh)',
          'phone': '+91 98765 43203',
          'vehicleType': 'auto',
          'vehicleNumber': 'ZYRO-201',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': 0.0042,
          'lngOffset': -0.0031,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 4)),
        },
        {
          'id': 'demo_driver_04',
          'name': 'ZYRO Driver 04 (Anand)',
          'phone': '+91 98765 43204',
          'vehicleType': 'auto',
          'vehicleNumber': 'ZYRO-202',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': -0.0068,
          'lngOffset': 0.0055,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 25)),
        },
        {
          'id': 'demo_driver_05',
          'name': 'ZYRO Driver 05 (Syed)',
          'phone': '+91 98765 43205',
          'vehicleType': 'auto',
          'vehicleNumber': 'ZYRO-203',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': 0.0095,
          'lngOffset': 0.0072,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 55)),
        },
      ];
    } else {
      // Cab / Prime
      driverConfigs = [
        {
          'id': 'demo_driver_05',
          'name': 'ZYRO Driver 05 (Vikram)',
          'phone': '+91 98765 43205',
          'vehicleType': rideType,
          'vehicleNumber': 'ZYRO-301',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': 0.0048,
          'lngOffset': 0.0039,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 5)),
        },
        {
          'id': 'demo_driver_01',
          'name': 'ZYRO Driver 01 (Pradeep)',
          'phone': '+91 98765 43201',
          'vehicleType': rideType,
          'vehicleNumber': 'ZYRO-302',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': -0.0071,
          'lngOffset': -0.0045,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 22)),
        },
        {
          'id': 'demo_driver_02',
          'name': 'ZYRO Driver 02 (Kiran)',
          'phone': '+91 98765 43202',
          'vehicleType': rideType,
          'vehicleNumber': 'ZYRO-303',
          'isOnline': true,
          'isAvailable': true,
          'latOffset': 0.0112,
          'lngOffset': -0.0088,
          'lastRideCompletedAt': now.subtract(const Duration(minutes: 50)),
        },
      ];
    }

    return driverConfigs.map((cfg) {
      return DriverModel(
        id: cfg['id'] as String,
        name: cfg['name'] as String,
        phone: cfg['phone'] as String,
        vehicleType: cfg['vehicleType'] as String,
        vehicleNumber: cfg['vehicleNumber'] as String,
        isOnline: cfg['isOnline'] as bool,
        isAvailable: cfg['isAvailable'] as bool,
        latitude: pickupLat + (cfg['latOffset'] as double),
        longitude: pickupLng + (cfg['lngOffset'] as double),
        lastRideCompletedAt: cfg['lastRideCompletedAt'] as DateTime?,
      );
    }).toList();
  }

  /// Filters nearby eligible drivers within strict 2.0 KM radius.
  List<DriverModel> findEligibleDrivers({
    required List<DriverModel> pool,
    required double pickupLat,
    required double pickupLng,
    required String rideType,
    double maxRadiusKm = 2.0,
  }) {
    return pool.where((driver) {
      if (!driver.isOnline || !driver.isAvailable) return false;
      if (driver.vehicleType.toLowerCase() != rideType.toLowerCase()) return false;
      final dist = calculateDistanceKm(
        pickupLat,
        pickupLng,
        driver.latitude,
        driver.longitude,
      );
      return dist <= maxRadiusKm;
    }).toList();
  }

  /// Selects exactly ONE mandatory backup driver based on:
  /// 1. Most recently completed previous ride (lastRideCompletedAt descending).
  /// 2. Deterministic fallback: nearest eligible driver.
  DriverModel? selectBackupDriver(
    List<DriverModel> eligibleDrivers,
    double pickupLat,
    double pickupLng,
  ) {
    if (eligibleDrivers.isEmpty) return null;

    final sorted = List<DriverModel>.from(eligibleDrivers);
    sorted.sort((a, b) {
      final timeA = a.lastRideCompletedAt;
      final timeB = b.lastRideCompletedAt;

      // 1. Check lastRideCompletedAt (most recent first)
      if (timeA != null && timeB != null) {
        final cmp = timeB.compareTo(timeA);
        if (cmp != 0) return cmp;
      } else if (timeA != null && timeB == null) {
        return -1;
      } else if (timeA == null && timeB != null) {
        return 1;
      }

      // 2. Fallback: nearest distance
      final distA = calculateDistanceKm(pickupLat, pickupLng, a.latitude, a.longitude);
      final distB = calculateDistanceKm(pickupLat, pickupLng, b.latitude, b.longitude);
      if (distA != distB) return distA.compareTo(distB);

      return a.id.compareTo(b.id);
    });

    return sorted.first;
  }

  /// Initiates the 120-second ride allocation process and synchronizes to Cloud Firestore.
  DemoRideState startRideAllocation({
    required String riderId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required String rideType,
    required double fare,
    String? pickupAddress,
    String? destinationAddress,
  }) {
    _cancelTimer();
    _firestoreRideSubscription?.cancel();
    _isLockAcquired = false;

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(seconds: 120));
    final rideId = 'ride_${now.millisecondsSinceEpoch}';

    // 1. Generate & filter eligible drivers
    final pool = generateMockDrivers(
      pickupLat: pickupLatitude,
      pickupLng: pickupLongitude,
      rideType: rideType,
    );

    final eligible = findEligibleDrivers(
      pool: pool,
      pickupLat: pickupLatitude,
      pickupLng: pickupLongitude,
      rideType: rideType,
    );

    // Compute driver distances
    final Map<String, double> distances = {};
    for (final d in eligible) {
      distances[d.id] = calculateDistanceKm(
        pickupLatitude,
        pickupLongitude,
        d.latitude,
        d.longitude,
      );
    }

    // 2. Select ONE mandatory backup driver
    final backupDriver = selectBackupDriver(
      eligible,
      pickupLatitude,
      pickupLongitude,
    );

    final eligibleIds = eligible.map((d) => d.id).toList();

    // 3. Create initial RideModel
    final ride = RideModel(
      id: rideId,
      riderId: riderId,
      driverId: null,
      backupDriverId: backupDriver?.id,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      rideType: rideType,
      fare: fare,
      status: eligible.isNotEmpty ? RideStatus.searching : RideStatus.noDriver,
      eligibleDriverIds: eligibleIds,
      requestedAt: now,
      expiresAt: expiresAt,
      assignedAt: null,
    );

    _currentState = DemoRideState(
      ride: ride,
      eligibleDrivers: eligible,
      driverDistancesKm: distances,
      backupDriver: backupDriver,
      assignedDriver: null,
      remainingSeconds: eligible.isNotEmpty ? 120 : 0,
      isCompleted: eligible.isEmpty,
      assignmentReason: eligible.isEmpty ? 'no_driver' : null,
    );

    notifyListeners();

    // 4. Synchronize ride document to Firestore so Driver Dashboard sees it in real time
    try {
      _rideService.requestRide(
        riderId: riderId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        rideType: rideType,
        fare: fare,
        pickupAddress: pickupAddress,
        destinationAddress: destinationAddress,
        backupDriverId: backupDriver?.id,
        eligibleDriverIds: eligibleIds,
        customRideId: rideId,
      ).catchError((e) {
        debugPrint('[DemoRideAllocationService] Firestore sync skipped: $e');
        return rideId;
      });

      // 5. Listen to real-time updates on this ride document from Firestore
      _firestoreRideSubscription =
          _rideService.watchRide(rideId).listen((firestoreRide) {
        if (firestoreRide == null) return;

        if (firestoreRide.status == RideStatus.driverAssigned &&
            firestoreRide.driverId != null &&
            !_isLockAcquired) {
          _isLockAcquired = true;
          _cancelTimer();

        () async {
          DriverModel? fetchedDriver;
          try {
            fetchedDriver = await DriverService().getDriver(firestoreRide.driverId!);
          } catch (e) {
            debugPrint('Error fetching assigned driver model: $e');
          }

          final matchedDriver = fetchedDriver ??
              eligible.firstWhere(
                (d) => d.id == firestoreRide.driverId,
                orElse: () => DriverModel(
                  id: firestoreRide.driverId!,
                  name: 'ZYRO Assigned Driver',
                  phone: '+91 98765 00000',
                  vehicleType: rideType,
                  vehicleNumber: 'ZYRO-101',
                ),
              );

          final isBackup = firestoreRide.driverId == backupDriver?.id;

          _currentState = _currentState?.copyWith(
            ride: firestoreRide,
            assignedDriver: matchedDriver,
            remainingSeconds: 0,
            assignmentReason: isBackup ? 'backup_auto_assigned' : 'driver_accepted',
            isCompleted: true,
          );

          notifyListeners();
        }();
      } else if (firestoreRide.status == RideStatus.noDriver &&
          !_isLockAcquired) {
          _isLockAcquired = true;
          _cancelTimer();
          _currentState = _currentState?.copyWith(
            ride: firestoreRide,
            remainingSeconds: 0,
            assignmentReason: 'no_driver',
            isCompleted: true,
          );
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('[DemoRideAllocationService] Firestore sync error: $e');
    }

    if (eligible.isNotEmpty) {
      _startCountdown();
    }

    return _currentState!;
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentState == null) {
        timer.cancel();
        return;
      }

      final nextSec = _currentState!.remainingSeconds - 1;

      if (nextSec <= 0) {
        timer.cancel();
        _currentState = _currentState!.copyWith(remainingSeconds: 0);
        _handleTimeout();
      } else {
        _currentState = _currentState!.copyWith(remainingSeconds: nextSec);
        notifyListeners();
      }
    });
  }

  /// Handles 120-second timeout by automatically assigning the mandatory backup driver.
  Future<void> _handleTimeout() async {
    if (_isLockAcquired) return;
    if (_currentState == null) return;
    if (_currentState!.ride.status != RideStatus.searching) return;

    _isLockAcquired = true;
    _cancelTimer();

    final backup = _currentState!.backupDriver;

    // Execute atomic timeout transaction in Firestore
    await _rideService.timeoutRideTransaction(rideId: _currentState!.ride.id);

    if (backup != null && backup.isAvailable && backup.isOnline) {
      // Mandatory backup auto-assignment
      final updatedRide = _currentState!.ride.copyWith(
        driverId: backup.id,
        status: RideStatus.driverAssigned,
        assignedAt: DateTime.now(),
      );

      _currentState = _currentState!.copyWith(
        ride: updatedRide,
        assignedDriver: backup,
        remainingSeconds: 0,
        assignmentReason: 'backup_auto_assigned',
        isCompleted: true,
      );
    } else {
      // Backup unavailable
      final updatedRide = _currentState!.ride.copyWith(
        status: RideStatus.noDriver,
      );

      _currentState = _currentState!.copyWith(
        ride: updatedRide,
        remainingSeconds: 0,
        assignmentReason: 'no_driver',
        isCompleted: true,
      );
    }

    notifyListeners();
  }

  /// Fast-forward simulation: triggers timeout immediately to demo automatic backup assignment.
  void triggerTimeoutNow() {
    if (_currentState == null || _currentState!.isCompleted) return;
    _handleTimeout();
  }

  /// Driver acceptance action (race-safe).
  ///
  /// Returns true if driver won the acceptance, false if ride already assigned/expired.
  Future<bool> acceptRide(String driverId) async {
    if (_isLockAcquired) return false;
    if (_currentState == null) return false;
    if (_currentState!.ride.status != RideStatus.searching) return false;
    if (_currentState!.remainingSeconds <= 0) return false;

    // Execute atomic transaction in Firestore
    final result = await _rideService.acceptRideTransaction(
      rideId: _currentState!.ride.id,
      driverId: driverId,
    );

    if (result['success'] != true) {
      return false;
    }

    // Acquire lock atomically for this demo session
    _isLockAcquired = true;
    _cancelTimer();

    // Find driver
    final driver = _currentState!.eligibleDrivers.firstWhere(
      (d) => d.id == driverId,
      orElse: () => _currentState!.eligibleDrivers.first,
    );

    final updatedRide = _currentState!.ride.copyWith(
      driverId: driver.id,
      status: RideStatus.driverAssigned,
      assignedAt: DateTime.now(),
    );

    _currentState = _currentState!.copyWith(
      ride: updatedRide,
      assignedDriver: driver,
      assignmentReason: 'driver_accepted',
      isCompleted: true,
    );

    notifyListeners();
    return true;
  }

  /// Cancels the current demo ride.
  Future<void> cancelRide() async {
    _cancelTimer();
    _firestoreRideSubscription?.cancel();
    _isLockAcquired = true;

    if (_currentState != null) {
      try {
        await _rideService.cancelRide(_currentState!.ride.id);
      } catch (e) {
        debugPrint('[DemoRideAllocationService] Firestore cancel skipped: $e');
      }

      final updatedRide = _currentState!.ride.copyWith(
        status: RideStatus.cancelled,
      );
      _currentState = _currentState!.copyWith(
        ride: updatedRide,
        isCompleted: true,
        assignmentReason: 'cancelled',
      );
      notifyListeners();
    }
  }

  /// Resets the demo session.
  void reset() {
    _cancelTimer();
    _firestoreRideSubscription?.cancel();
    _isLockAcquired = false;
    _currentState = null;
    notifyListeners();
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    _firestoreRideSubscription?.cancel();
    super.dispose();
  }
}
