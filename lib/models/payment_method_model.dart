import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user saved payment preference (UPI, Masked Card, or Cash).
/// NEVER stores CVV, PIN, or raw sensitive credentials.
class PaymentMethodModel {
  final String id;
  final String userId;
  final String type; // 'upi', 'card', 'cash'
  final String displayName;
  final String? last4;
  final String? upiId;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentMethodModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.displayName,
    this.last4,
    this.upiId,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return PaymentMethodModel(
      id: id.isNotEmpty ? id : (map['id'] as String? ?? ''),
      userId: map['userId'] as String? ?? '',
      type: map['type'] as String? ?? 'cash',
      displayName: map['displayName'] as String? ?? '',
      last4: map['last4'] as String?,
      upiId: map['upiId'] as String?,
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  factory PaymentMethodModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentMethodModel.fromMap(data, id: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'displayName': displayName,
      'last4': last4,
      'upiId': upiId,
      'isDefault': isDefault,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PaymentMethodModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? displayName,
    String? last4,
    String? upiId,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      last4: last4 ?? this.last4,
      upiId: upiId ?? this.upiId,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
