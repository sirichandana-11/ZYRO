import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';

/// Service responsible for managing ride documents and real-time updates in Firestore.
class RideService {
  static final RideService _instance = RideService._internal();
  factory RideService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return RideService._withFirestore(firestore);
    }
    return _instance;
  }
  RideService._internal() : _firestore = FirebaseFirestore.instance;
  RideService._withFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _ridesCollection =>
      _firestore.collection('rides');

  /// Creates a new ride request document in the 'rides' Firestore collection.
  ///
  /// - Sets [requestedAt] using Firestore server timestamp / current time.
  /// - Sets [expiresAt] to exactly 120 seconds after creation.
  /// - Sets initial [status] to [RideStatus.searching].
  ///
  /// Returns the newly generated Firestore ride document ID.
  Future<String> requestRide({
    required String riderId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    required String rideType,
    required double fare,
    String? pickupAddress,
    String? destinationAddress,
    String? backupDriverId,
    List<String> eligibleDriverIds = const [],
    String? customRideId,
  }) async {
    final docRef = customRideId != null && customRideId.isNotEmpty
        ? _ridesCollection.doc(customRideId)
        : _ridesCollection.doc();

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(seconds: 120));

    final rideData = <String, dynamic>{
      'id': docRef.id,
      'riderId': riderId,
      'driverId': null,
      'backupDriverId': backupDriverId,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'destinationLatitude': destinationLatitude,
      'destinationLongitude': destinationLongitude,
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'rideType': rideType,
      'fare': fare,
      'status': RideStatus.searching,
      'eligibleDriverIds': eligibleDriverIds,
      'requestedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'assignedAt': null,
    };

    await docRef.set(rideData, SetOptions(merge: true));
    return docRef.id;
  }

  /// Listens to a ride document in real time.
  ///
  /// Emits a [RideModel] whenever the document updates, or `null` if the document does not exist.
  Stream<RideModel?> watchRide(String rideId) {
    if (rideId.isEmpty) {
      return Stream.value(null);
    }

    return _ridesCollection.doc(rideId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return RideModel.fromFirestore(snapshot);
    });
  }

  /// Listens for real-time incoming ride requests offered to a specific driver.
  ///
  /// Filters for rides with status `searching` where the driver is included in
  /// `eligibleDriverIds` (or all searching rides if eligibleDriverIds is not restricted).
  Stream<List<RideModel>> watchRideRequestsForDriver(String driverId) {
    return _ridesCollection
        .where('status', isEqualTo: RideStatus.searching)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RideModel.fromFirestore(doc))
          .where((ride) {
            // Check not expired locally
            if (ride.expiresAt != null &&
                DateTime.now().isAfter(ride.expiresAt!)) {
              return false;
            }
            // Check driver eligibility list
            if (ride.eligibleDriverIds.isNotEmpty) {
              return ride.eligibleDriverIds.contains(driverId);
            }
            return true;
          })
          .toList();
    });
  }

  /// Executes an atomic, race-safe Firestore transaction for driver acceptance.
  ///
  /// The first driver to accept wins the ride. If another driver already accepted
  /// or if the 120s timer expired, the transaction safely fails without overwriting.
  Future<Map<String, dynamic>> acceptRideTransaction({
    required String rideId,
    required String driverId,
  }) async {
    final rideRef = _ridesCollection.doc(rideId);
    final driverRef = _firestore.collection('drivers').doc(driverId);

    try {
      final result = await _firestore.runTransaction((transaction) async {
        final rideDoc = await transaction.get(rideRef);
        final driverDoc = await transaction.get(driverRef);

        if (!rideDoc.exists || rideDoc.data() == null) {
          return {
            'success': false,
            'message': 'Ride request no longer exists.',
          };
        }

        final rideData = rideDoc.data()!;
        final currentStatus = rideData['status'] as String? ?? '';

        // 1. Verify ride status
        if (currentStatus != RideStatus.searching) {
          return {
            'success': false,
            'message': 'Ride is no longer available (Status: $currentStatus).',
          };
        }

        // 2. Verify expiration
        final expiresAt = rideData['expiresAt'];
        if (expiresAt != null) {
          DateTime? expireTime;
          if (expiresAt is Timestamp) {
            expireTime = expiresAt.toDate();
          } else if (expiresAt is DateTime) {
            expireTime = expiresAt;
          }
          if (expireTime != null && DateTime.now().isAfter(expireTime)) {
            return {
              'success': false,
              'message': 'Ride request has expired (120s timeout reached).',
            };
          }
        }

        // 3. Verify driver status
        if (driverDoc.exists && driverDoc.data() != null) {
          final driverData = driverDoc.data()!;
          final isOnline = driverData['isOnline'] as bool? ?? false;
          final isAvailable = driverData['isAvailable'] as bool? ?? false;
          if (!isOnline || !isAvailable) {
            return {
              'success': false,
              'message': 'Driver is no longer online or available.',
            };
          }
        }

        // 4. Verify no driver already assigned
        if (rideData['driverId'] != null) {
          return {
            'success': false,
            'message': 'Ride already accepted by another driver.',
          };
        }

        // 5. Atomically assign driver and mark driver busy
        transaction.update(rideRef, {
          'driverId': driverId,
          'status': RideStatus.driverAssigned,
          'assignedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(
          driverRef,
          {
            'isAvailable': false,
            'activeRideId': rideId,
          },
          SetOptions(merge: true),
        );

        return {
          'success': true,
          'message': 'Ride accepted successfully!',
          'rideId': rideId,
          'driverId': driverId,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Transaction error accepting ride: ${e.toString()}',
      };
    }
  }

  /// Executes atomic timeout assignment: automatically assigns mandatory backup driver.
  Future<Map<String, dynamic>> timeoutRideTransaction({
    required String rideId,
  }) async {
    final rideRef = _ridesCollection.doc(rideId);

    try {
      final result = await _firestore.runTransaction((transaction) async {
        final rideDoc = await transaction.get(rideRef);
        if (!rideDoc.exists || rideDoc.data() == null) {
          return {'success': false, 'reason': 'ride_not_found'};
        }

        final rideData = rideDoc.data()!;
        final currentStatus = rideData['status'] as String? ?? '';

        if (currentStatus != RideStatus.searching) {
          return {
            'success': true,
            'alreadyProcessed': true,
            'status': currentStatus,
          };
        }

        final backupDriverId = rideData['backupDriverId'] as String?;

        if (backupDriverId != null && backupDriverId.isNotEmpty) {
          final driverRef = _firestore.collection('drivers').doc(backupDriverId);
          final driverDoc = await transaction.get(driverRef);

          final driverData = driverDoc.exists ? driverDoc.data() : null;
          final isBackupAvailable = driverData != null &&
              (driverData['isOnline'] as bool? ?? false) &&
              (driverData['isAvailable'] as bool? ?? false);

          if (isBackupAvailable) {
            // Automatically assign the mandatory backup driver
            transaction.update(rideRef, {
              'driverId': backupDriverId,
              'status': RideStatus.driverAssigned,
              'assignedAt': FieldValue.serverTimestamp(),
            });

            transaction.set(
              driverRef,
              {
                'isAvailable': false,
                'activeRideId': rideId,
              },
              SetOptions(merge: true),
            );

            return {
              'success': true,
              'assigned': true,
              'driverId': backupDriverId,
              'status': RideStatus.driverAssigned,
            };
          }
        }

        // Backup unavailable or missing
        transaction.update(rideRef, {
          'status': RideStatus.noDriver,
        });

        return {
          'success': true,
          'assigned': false,
          'status': RideStatus.noDriver,
          'reason': 'backup_unavailable',
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing timeout transaction: ${e.toString()}',
      };
    }
  }

  /// Cancels an active ride in Firestore.
  Future<void> cancelRide(String rideId) async {
    if (rideId.isEmpty) return;
    await _ridesCollection.doc(rideId).update({
      'status': RideStatus.cancelled,
    });
  }
}
