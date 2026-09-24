import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ride_model.dart';
import './websocket_service.dart';

/// Service responsible for managing ride documents and real-time updates in Firestore.
class RideService {
  static final RideService _instance = RideService._internal();
  factory RideService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return RideService._withFirestore(firestore);
    }
    return _instance;
  }
  RideService._internal() : _customFirestore = null;
  RideService._withFirestore(this._customFirestore);

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

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

  /// Cancels an active ride in Firestore with atomic transaction and driver release.
  ///
  /// Race-Safe Invariant:
  /// - If `status == searching`, atomically transitions to `cancelled`.
  /// - If `status == driver_assigned` or `driver_arriving`, atomically transitions to `cancelled` and releases assigned driver.
  /// - If already terminal, returns idempotent success without throwing.
  Future<Map<String, dynamic>> cancelRideTransaction({
    required String rideId,
    String? riderId,
    String? reason,
  }) async {
    if (rideId.isEmpty) {
      return {'success': false, 'message': 'rideId is required'};
    }

    final rideRef = _ridesCollection.doc(rideId);

    try {
      final result = await _firestore.runTransaction((transaction) async {
        final rideDoc = await transaction.get(rideRef);
        if (!rideDoc.exists || rideDoc.data() == null) {
          return {
            'success': false,
            'message': 'Ride document not found',
            'status': 'not_found',
          };
        }

        final rideData = rideDoc.data()!;
        final currentStatus = rideData['status'] as String? ?? '';
        final currentRiderId = rideData['riderId'] as String? ?? '';
        final assignedDriverId = rideData['driverId'] as String?;

        // Verify rider authorization if riderId provided
        if (riderId != null && riderId.isNotEmpty && currentRiderId.isNotEmpty && currentRiderId != riderId) {
          return {
            'success': false,
            'message': 'Unauthorized: authenticated rider does not own this ride',
            'status': currentStatus,
          };
        }

        // Idempotent handling if already cancelled
        if (currentStatus == RideStatus.cancelled) {
          return {
            'success': true,
            'status': RideStatus.cancelled,
            'alreadyCancelled': true,
          };
        }

        // Terminal states cannot be cancelled
        if (currentStatus == RideStatus.completed || currentStatus == RideStatus.noDriver) {
          return {
            'success': false,
            'status': currentStatus,
            'message': 'Cannot cancel ride in terminal state $currentStatus',
          };
        }

        // Active on-trip state
        if (currentStatus == RideStatus.rideStarted) {
          return {
            'success': false,
            'status': currentStatus,
            'message': 'Ride is already in progress and cannot be cancelled directly.',
          };
        }

        final updateData = <String, dynamic>{
          'status': RideStatus.cancelled,
          'cancelledAt': FieldValue.serverTimestamp(),
          if (reason != null && reason.isNotEmpty) 'cancelReason': reason,
        };

        transaction.update(rideRef, updateData);

        // If driver was assigned, atomically release the driver
        if ((currentStatus == RideStatus.driverAssigned || currentStatus == RideStatus.driverArriving) &&
            assignedDriverId != null &&
            assignedDriverId.isNotEmpty) {
          final driverRef = _firestore.collection('drivers').doc(assignedDriverId);
          transaction.update(driverRef, {
            'isAvailable': true,
            'activeRideId': null,
          });
        }

        return {
          'success': true,
          'status': RideStatus.cancelled,
          'previousStatus': currentStatus,
          'releasedDriverId': assignedDriverId,
        };
      });

      // Broadcast WebSocket notification to clear driver requests and alert subscribers
      try {
        WebSocketService.instance.sendRideCancelled(
          rideId: rideId,
          reason: reason ?? 'Rider cancelled request',
        );
      } catch (wsErr) {
        debugPrint('[RideService] WS cancel notification warning: $wsErr');
      }

      return result;
    } catch (e) {
      debugPrint('[RideService] cancelRideTransaction error: $e');
      return {
        'success': false,
        'message': 'Failed to cancel ride: ${e.toString()}',
      };
    }
  }

  /// Cancels an active ride in Firestore (convenience wrapper around cancelRideTransaction).
  Future<void> cancelRide(String rideId, {String? riderId, String? reason}) async {
    await cancelRideTransaction(rideId: rideId, riderId: riderId, reason: reason);
  }

  /// Updates ride status (e.g. driver_arriving -> driver_arrived -> ride_started -> completed).
  Future<void> updateRideStatus({
    required String rideId,
    required String status,
    String? driverId,
  }) async {
    if (rideId.isEmpty) return;

    final updateData = <String, dynamic>{
      'status': status,
    };

    final now = FieldValue.serverTimestamp();
    if (status == RideStatus.driverArriving) {
      updateData['arrivingAt'] = now;
    } else if (status == RideStatus.driverArrived) {
      updateData['arrivedAt'] = now;
    } else if (status == RideStatus.rideStarted) {
      updateData['startedAt'] = now;
    } else if (status == RideStatus.completed) {
      updateData['completedAt'] = now;
    }

    await _ridesCollection.doc(rideId).update(updateData);

    // If completed, update driver state
    if (status == RideStatus.completed && driverId != null && driverId.isNotEmpty) {
      await _firestore.collection('drivers').doc(driverId).update({
        'isAvailable': true,
        'activeRideId': null,
        'lastRideCompletedAt': FieldValue.serverTimestamp(),
        'completedRidesCount': FieldValue.increment(1),
      });
    }
  }

  /// Listens to ride history for a specific rider (real Firestore stream).
  Stream<List<RideModel>> watchRidesForRider(String riderId, {int limit = 30}) {
    if (riderId.isEmpty) return Stream.value([]);

    return _ridesCollection
        .where('riderId', isEqualTo: riderId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs.map((doc) => RideModel.fromFirestore(doc)).toList();
      // Sort client-side by requestedAt descending to avoid mandatory Firestore composite index requirement
      rides.sort((a, b) {
        final timeA = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
      return rides;
    });
  }

  /// Listens to ride history for a specific driver.
  Stream<List<RideModel>> watchRidesForDriver(String driverId, {int limit = 30}) {
    if (driverId.isEmpty) return Stream.value([]);

    return _ridesCollection
        .where('driverId', isEqualTo: driverId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs.map((doc) => RideModel.fromFirestore(doc)).toList();
      rides.sort((a, b) {
        final timeA = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });
      return rides;
    });
  }

  /// Rates a completed ride and atomically updates the driver's aggregate rating.
  Future<bool> rateRide({
    required String rideId,
    required String riderId,
    String? driverId,
    required int rating,
    String? feedback,
  }) async {
    if (rideId.isEmpty || rating < 1 || rating > 5) {
      return false;
    }

    final rideRef = _ridesCollection.doc(rideId);
    final ratingRef = _firestore.collection('ratings').doc('${rideId}_$riderId');

    try {
      await _firestore.runTransaction((transaction) async {
        final rideDoc = await transaction.get(rideRef);

        if (!rideDoc.exists) throw Exception('Ride not found');

        final rideData = rideDoc.data()!;
        if (rideData['rating'] != null) {
          throw Exception('Ride already rated');
        }

        final targetDriverId = (driverId != null && driverId.isNotEmpty)
            ? driverId
            : (rideData['driverId'] as String? ?? '');

        // 1. Record rating in ratings collection
        transaction.set(ratingRef, {
          'rideId': rideId,
          'riderId': riderId,
          'driverId': targetDriverId,
          'rating': rating,
          'feedback': feedback?.trim() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Update ride document with rating
        transaction.update(rideRef, {
          'rating': rating,
          'ratingFeedback': feedback?.trim() ?? '',
        });

        // 3. Atomically update driver aggregate rating if driver exists
        if (targetDriverId.isNotEmpty) {
          final driverRef = _firestore.collection('drivers').doc(targetDriverId);
          final driverDoc = await transaction.get(driverRef);
          if (driverDoc.exists && driverDoc.data() != null) {
            final driverData = driverDoc.data()!;
            final currentSum = (driverData['ratingSum'] as num?)?.toDouble() ?? 0.0;
            final currentCount = (driverData['ratingCount'] as num?)?.toInt() ?? 0;

            final newSum = currentSum + rating;
            final newCount = currentCount + 1;
            final newAvg = newCount > 0 ? (newSum / newCount) : 5.0;

            transaction.update(driverRef, {
              'ratingSum': newSum,
              'ratingCount': newCount,
              'averageRating': double.parse(newAvg.toStringAsFixed(2)),
            });
          }
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
