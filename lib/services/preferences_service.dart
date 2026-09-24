import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Service managing user notification and app settings preferences in Firestore (`users/{uid}/preferences`).
class PreferencesService {
  static PreferencesService? _instance;
  factory PreferencesService({FirebaseFirestore? firestore}) {
    if (firestore != null) {
      return PreferencesService._withFirestore(firestore);
    }
    _instance ??= PreferencesService._internal();
    return _instance!;
  }
  PreferencesService._internal() : _customFirestore = null;
  PreferencesService._withFirestore(this._customFirestore);

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  /// Global notifier for theme mode changes
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  DocumentReference<Map<String, dynamic>> _prefDoc(String uid, String type) =>
      _firestore.collection('users').doc(uid).collection('preferences').doc(type);

  /// Default notification preferences
  static const Map<String, bool> defaultNotificationPrefs = {
    'driverAssigned': true,
    'driverArriving': true,
    'rideStarted': true,
    'rideCompleted': true,
    'rideCancelled': true,
    'promotions': false,
    'securityAlerts': true,
  };

  /// Default app preferences
  static const Map<String, dynamic> defaultAppPrefs = {
    'themeMode': 'system',
    'distanceUnit': 'km',
    'mapStyle': 'standard',
  };

  /// Parses a string into a [ThemeMode] enum.
  static ThemeMode parseThemeMode(String? mode) {
    if (mode == null) return ThemeMode.system;
    switch (mode.toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  /// Serializes a [ThemeMode] enum into its lowercase string representation.
  static String serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Loads and applies the initial theme mode from Firestore or cache
  Future<void> initThemeMode(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      final doc = await _prefDoc(uid, 'app').get();
      if (doc.exists && doc.data() != null) {
        final themeStr = doc.data()!['themeMode'] as String?;
        if (themeStr != null) {
          _applyThemeMode(themeStr);
        }
      }
    } catch (_) {
      // Offline fallback: retains current in-memory ThemeMode
    }
  }

  /// Streams notification preferences for a user.
  Stream<Map<String, bool>> watchNotificationPreferences(String uid) {
    if (uid.isEmpty) return Stream.value(defaultNotificationPrefs);

    return _prefDoc(uid, 'notifications').snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return defaultNotificationPrefs;
      }
      final data = snapshot.data()!;
      return {
        'driverAssigned': data['driverAssigned'] as bool? ?? true,
        'driverArriving': data['driverArriving'] as bool? ?? true,
        'rideStarted': data['rideStarted'] as bool? ?? true,
        'rideCompleted': data['rideCompleted'] as bool? ?? true,
        'rideCancelled': data['rideCancelled'] as bool? ?? true,
        'promotions': data['promotions'] as bool? ?? false,
        'securityAlerts': data['securityAlerts'] as bool? ?? true,
      };
    });
  }

  /// Updates notification preferences for a user.
  Future<void> updateNotificationPreferences(String uid, Map<String, bool> prefs) async {
    if (uid.isEmpty) return;
    await _prefDoc(uid, 'notifications').set({
      ...prefs,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Streams app settings preferences for a user.
  Stream<Map<String, dynamic>> watchAppPreferences(String uid) {
    if (uid.isEmpty) return Stream.value(defaultAppPrefs);

    return _prefDoc(uid, 'app').snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return defaultAppPrefs;
      }
      final data = snapshot.data()!;
      final themeStr = data['themeMode'] as String? ?? 'system';
      _applyThemeMode(themeStr);

      return {
        'themeMode': themeStr,
        'distanceUnit': data['distanceUnit'] as String? ?? 'km',
        'mapStyle': data['mapStyle'] as String? ?? 'standard',
      };
    });
  }

  /// Updates app settings for a user.
  Future<void> updateAppPreference(String uid, String key, dynamic value) async {
    if (uid.isEmpty) return;

    if (key == 'themeMode' && value is String) {
      _applyThemeMode(value);
    }

    await _prefDoc(uid, 'app').set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _applyThemeMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'dark':
        if (themeModeNotifier.value != ThemeMode.dark) {
          themeModeNotifier.value = ThemeMode.dark;
        }
        break;
      case 'light':
        if (themeModeNotifier.value != ThemeMode.light) {
          themeModeNotifier.value = ThemeMode.light;
        }
        break;
      default:
        if (themeModeNotifier.value != ThemeMode.system) {
          themeModeNotifier.value = ThemeMode.system;
        }
    }
  }
}
