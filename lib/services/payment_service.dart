import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_method_model.dart';
import '../models/ride_model.dart';

/// Service managing user payment methods and payment history in Firestore (`users/{uid}/paymentMethods`).
/// NEVER stores CVV, PIN, or raw sensitive credentials.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return PaymentService._withFirestore(firestore);
    }
    return _instance;
  }
  PaymentService._internal() : _firestore = FirebaseFirestore.instance;
  PaymentService._withFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _methodsCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('paymentMethods');

  /// Streams saved payment methods for a user.
  Stream<List<PaymentMethodModel>> watchPaymentMethods(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _methodsCollection(uid).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => PaymentMethodModel.fromFirestore(doc))
          .toList();
      list.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return a.displayName.compareTo(b.displayName);
      });
      return list;
    });
  }

  /// Adds a new payment method for a user.
  Future<String> addPaymentMethod({
    required String uid,
    required String type,
    required String displayName,
    String? upiId,
    String? last4,
    bool isDefault = false,
  }) async {
    if (uid.isEmpty) throw 'User must be authenticated';
    if (displayName.trim().isEmpty) throw 'Payment method title is required';

    if (type == 'upi') {
      if (upiId == null || !upiId.contains('@')) {
        throw 'Please enter a valid UPI ID (e.g. name@upi)';
      }
    } else if (type == 'card') {
      if (last4 == null || last4.length != 4 || int.tryParse(last4) == null) {
        throw 'Please enter valid last 4 digits of the card';
      }
    }

    final docRef = _methodsCollection(uid).doc();

    if (isDefault) {
      // Clear existing default flags
      final existing = await _methodsCollection(uid).get();
      final batch = _firestore.batch();
      for (final doc in existing.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
      await batch.commit();
    }

    final method = PaymentMethodModel(
      id: docRef.id,
      userId: uid,
      type: type.toLowerCase(),
      displayName: displayName.trim(),
      upiId: upiId?.trim(),
      last4: last4?.trim(),
      isDefault: isDefault,
    );

    await docRef.set(method.toMap());
    return docRef.id;
  }

  /// Sets a payment method as the default method for the user.
  Future<void> setDefaultPaymentMethod({
    required String uid,
    required String paymentMethodId,
  }) async {
    if (uid.isEmpty || paymentMethodId.isEmpty) return;

    final existing = await _methodsCollection(uid).get();
    final batch = _firestore.batch();

    for (final doc in existing.docs) {
      batch.update(doc.reference, {
        'isDefault': doc.id == paymentMethodId,
      });
    }

    await batch.commit();
  }

  /// Removes a payment method.
  Future<void> deletePaymentMethod({
    required String uid,
    required String paymentMethodId,
  }) async {
    if (uid.isEmpty || paymentMethodId.isEmpty) return;
    await _methodsCollection(uid).doc(paymentMethodId).delete();
  }

  /// Streams real ride payment transaction history from Firestore.
  Stream<List<RideModel>> watchPaymentHistory(String uid, {int limit = 30}) {
    if (uid.isEmpty) return Stream.value([]);

    return _firestore
        .collection('rides')
        .where('riderId', isEqualTo: uid)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final rides = snapshot.docs
          .map((doc) => RideModel.fromFirestore(doc))
          .where((r) => r.status == RideStatus.completed)
          .toList();

      rides.sort((a, b) {
        final timeA = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeB.compareTo(timeA);
      });

      return rides;
    });
  }
}
