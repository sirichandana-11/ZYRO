import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saved_place_model.dart';

/// Service managing user saved locations in Firestore (`users/{uid}/savedPlaces/{placeId}`).
class SavedPlacesService {
  static final SavedPlacesService _instance = SavedPlacesService._internal();
  factory SavedPlacesService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return SavedPlacesService._withFirestore(firestore);
    }
    return _instance;
  }
  SavedPlacesService._internal() : _firestore = FirebaseFirestore.instance;
  SavedPlacesService._withFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _placesCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('savedPlaces');

  /// Streams saved places for the specified user in real time.
  Stream<List<SavedPlaceModel>> watchSavedPlaces(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _placesCollection(uid)
        .snapshots()
        .map((snapshot) {
      final places = snapshot.docs
          .map((doc) => SavedPlaceModel.fromFirestore(doc))
          .toList();
      // Sort: Home first, Work second, others next
      places.sort((a, b) {
        int priority(String tag) {
          if (tag == 'home') return 0;
          if (tag == 'work') return 1;
          return 2;
        }
        final pA = priority(a.tag);
        final pB = priority(b.tag);
        if (pA != pB) return pA.compareTo(pB);
        return a.title.compareTo(b.title);
      });
      return places;
    });
  }

  /// Adds a new saved place for the user.
  Future<String> addSavedPlace({
    required String uid,
    required String tag,
    required String title,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    if (uid.isEmpty) throw 'User must be authenticated';
    if (title.trim().isEmpty) throw 'Place name is required';
    if (address.trim().isEmpty) throw 'Address is required';
    if (latitude == 0.0 && longitude == 0.0) throw 'Valid location coordinates are required';

    final docRef = _placesCollection(uid).doc();
    final place = SavedPlaceModel(
      id: docRef.id,
      userId: uid,
      tag: tag.toLowerCase(),
      title: title.trim(),
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
    );

    await docRef.set(place.toMap());
    return docRef.id;
  }

  /// Updates an existing saved place.
  Future<void> updateSavedPlace({
    required String uid,
    required String placeId,
    required String tag,
    required String title,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    if (uid.isEmpty || placeId.isEmpty) throw 'Invalid place identifier';
    if (title.trim().isEmpty) throw 'Place name is required';
    if (address.trim().isEmpty) throw 'Address is required';

    await _placesCollection(uid).doc(placeId).update({
      'tag': tag.toLowerCase(),
      'title': title.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a saved place.
  Future<void> deleteSavedPlace({
    required String uid,
    required String placeId,
  }) async {
    if (uid.isEmpty || placeId.isEmpty) return;
    await _placesCollection(uid).doc(placeId).delete();
  }
}
