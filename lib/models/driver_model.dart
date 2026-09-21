import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a driver in the ZYRO platform.
class DriverModel {
  final String id;
  final String name;
  final String phone;
  final String vehicleType;
  final String vehicleNumber;
  final bool isOnline;
  final bool isAvailable;
  final double latitude;
  final double longitude;
  final DateTime? lastRideCompletedAt;
  final String? activeRideId;

  const DriverModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.vehicleNumber,
    this.isOnline = false,
    this.isAvailable = false,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.lastRideCompletedAt,
    this.activeRideId,
  });

  /// Creates a [DriverModel] from a Map and an optional document ID.
  factory DriverModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return DriverModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      vehicleType: map['vehicleType'] as String? ?? '',
      vehicleNumber: map['vehicleNumber'] as String? ?? '',
      isOnline: map['isOnline'] as bool? ?? false,
      isAvailable: map['isAvailable'] as bool? ?? false,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      lastRideCompletedAt: parseDateTime(map['lastRideCompletedAt']),
      activeRideId: map['activeRideId'] as String?,
    );
  }

  /// Creates a [DriverModel] from a Firestore [DocumentSnapshot].
  factory DriverModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return DriverModel.fromMap(data, id: doc.id);
  }

  /// Converts the [DriverModel] to a Map suitable for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'isOnline': isOnline,
      'isAvailable': isAvailable,
      'latitude': latitude,
      'longitude': longitude,
      'lastRideCompletedAt': lastRideCompletedAt != null
          ? Timestamp.fromDate(lastRideCompletedAt!)
          : null,
      'activeRideId': activeRideId,
    };
  }

  /// Creates a copy of this [DriverModel] with the given fields replaced with new values.
  DriverModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? vehicleType,
    String? vehicleNumber,
    bool? isOnline,
    bool? isAvailable,
    double? latitude,
    double? longitude,
    DateTime? lastRideCompletedAt,
    String? activeRideId,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastRideCompletedAt: lastRideCompletedAt ?? this.lastRideCompletedAt,
      activeRideId: activeRideId ?? this.activeRideId,
    );
  }
}
