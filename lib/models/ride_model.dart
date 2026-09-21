import 'package:cloud_firestore/cloud_firestore.dart';

/// Supported ride statuses in ZYRO.
class RideStatus {
  static const String searching = 'searching';
  static const String driverAssigned = 'driver_assigned';
  static const String driverArriving = 'driver_arriving';
  static const String rideStarted = 'ride_started';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String noDriver = 'no_driver';

  static const List<String> values = [
    searching,
    driverAssigned,
    driverArriving,
    rideStarted,
    completed,
    cancelled,
    noDriver,
  ];
}

/// Model representing a ride in the ZYRO platform.
class RideModel {
  final String id;
  final String riderId;
  final String? driverId;
  final String? backupDriverId;
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String? pickupAddress;
  final String? destinationAddress;
  final String rideType;
  final double fare;
  final String status;
  final List<String> eligibleDriverIds;
  final DateTime? requestedAt;
  final DateTime? expiresAt;
  final DateTime? assignedAt;

  const RideModel({
    required this.id,
    required this.riderId,
    this.driverId,
    this.backupDriverId,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.pickupAddress,
    this.destinationAddress,
    required this.rideType,
    required this.fare,
    this.status = RideStatus.searching,
    this.eligibleDriverIds = const [],
    this.requestedAt,
    this.expiresAt,
    this.assignedAt,
  });

  /// Creates a [RideModel] from a Map and an optional document ID.
  factory RideModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final rawEligible = map['eligibleDriverIds'];
    List<String> parsedEligible = [];
    if (rawEligible is List) {
      parsedEligible = rawEligible.map((e) => e.toString()).toList();
    }

    return RideModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      riderId: map['riderId'] as String? ?? '',
      driverId: map['driverId'] as String?,
      backupDriverId: map['backupDriverId'] as String?,
      pickupLatitude: (map['pickupLatitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (map['pickupLongitude'] as num?)?.toDouble() ?? 0.0,
      destinationLatitude: (map['destinationLatitude'] as num?)?.toDouble() ?? 0.0,
      destinationLongitude: (map['destinationLongitude'] as num?)?.toDouble() ?? 0.0,
      pickupAddress: map['pickupAddress'] as String?,
      destinationAddress: map['destinationAddress'] as String?,
      rideType: map['rideType'] as String? ?? '',
      fare: (map['fare'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? RideStatus.searching,
      eligibleDriverIds: parsedEligible,
      requestedAt: parseDateTime(map['requestedAt']),
      expiresAt: parseDateTime(map['expiresAt']),
      assignedAt: parseDateTime(map['assignedAt']),
    );
  }

  /// Creates a [RideModel] from a Firestore [DocumentSnapshot].
  factory RideModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RideModel.fromMap(data, id: doc.id);
  }

  /// Converts the [RideModel] to a Map suitable for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'driverId': driverId,
      'backupDriverId': backupDriverId,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'destinationLatitude': destinationLatitude,
      'destinationLongitude': destinationLongitude,
      if (pickupAddress != null) 'pickupAddress': pickupAddress,
      if (destinationAddress != null) 'destinationAddress': destinationAddress,
      'rideType': rideType,
      'fare': fare,
      'status': status,
      'eligibleDriverIds': eligibleDriverIds,
      'requestedAt': requestedAt != null ? Timestamp.fromDate(requestedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
    };
  }

  /// Creates a copy of this [RideModel] with the given fields replaced with new values.
  RideModel copyWith({
    String? id,
    String? riderId,
    String? driverId,
    String? backupDriverId,
    double? pickupLatitude,
    double? pickupLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    String? pickupAddress,
    String? destinationAddress,
    String? rideType,
    double? fare,
    String? status,
    List<String>? eligibleDriverIds,
    DateTime? requestedAt,
    DateTime? expiresAt,
    DateTime? assignedAt,
  }) {
    return RideModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      driverId: driverId ?? this.driverId,
      backupDriverId: backupDriverId ?? this.backupDriverId,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      rideType: rideType ?? this.rideType,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      eligibleDriverIds: eligibleDriverIds ?? this.eligibleDriverIds,
      requestedAt: requestedAt ?? this.requestedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }
}
