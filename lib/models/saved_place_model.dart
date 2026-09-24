import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user saved location (Home, Work, or Custom Landmark).
class SavedPlaceModel {
  final String id;
  final String userId;
  final String tag; // 'home', 'work', 'other'
  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SavedPlaceModel({
    required this.id,
    required this.userId,
    required this.tag,
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  factory SavedPlaceModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return SavedPlaceModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      userId: map['userId'] as String? ?? '',
      tag: map['tag'] as String? ?? 'other',
      title: map['title'] as String? ?? '',
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  factory SavedPlaceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SavedPlaceModel.fromMap(data, id: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'tag': tag,
      'title': title,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SavedPlaceModel copyWith({
    String? id,
    String? userId,
    String? tag,
    String? title,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedPlaceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tag: tag ?? this.tag,
      title: title ?? this.title,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
