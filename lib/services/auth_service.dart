import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Lazy mobile-only instance to prevent google_sign_in_web initialization on Chrome
  GoogleSignIn? _mobileGoogleSignIn;
  GoogleSignIn get _googleSignIn {
    if (kIsWeb) {
      throw UnsupportedError('GoogleSignIn must not be accessed on Web. Use FirebaseAuth.signInWithPopup instead.');
    }
    return _mobileGoogleSignIn ??= GoogleSignIn();
  }

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Check if user is currently logged in
  bool get isAuthenticated => _auth.currentUser != null;

  /// Fetches authoritative user role from Firestore (`users/{uid}`)
  Future<String> getUserRole(String uid) async {
    if (uid.isEmpty) return 'rider';
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final role = userDoc.data()!['role'] as String?;
        if (role != null && role.isNotEmpty) {
          return role.toLowerCase();
        }
      }

      // Check if driver profile exists directly in drivers collection
      final driverDoc = await _firestore.collection('drivers').doc(uid).get();
      if (driverDoc.exists) {
        // Backfill role in users collection
        await _firestore.collection('users').doc(uid).set({
          'id': uid,
          'role': 'driver',
          'email': currentUser?.email ?? '',
          'name': currentUser?.displayName ?? 'Driver',
        }, SetOptions(merge: true));
        return 'driver';
      }

      // Default fallback for new riders
      return 'rider';
    } catch (e) {
      debugPrint('Error fetching user role for $uid: $e');
      return 'rider';
    }
  }

  /// Validates email format
  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Validates full name
  String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  /// Validates phone number
  String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Validates vehicle number
  String? validateVehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vehicle registration number is required';
    }
    if (value.trim().length < 4) {
      return 'Please enter a valid registration number';
    }
    return null;
  }

  /// Validates vehicle type
  String? validateVehicleType(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vehicle type is required';
    }
    final validTypes = ['bike', 'auto', 'cab'];
    if (!validTypes.contains(value.trim().toLowerCase())) {
      return 'Vehicle type must be Bike, Auto, or Cab';
    }
    return null;
  }

  /// Stream user profile document from Firestore (`users/{uid}`)
  Stream<Map<String, dynamic>?> watchUserProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return snapshot.data();
    });
  }

  /// Fetches user profile document once from Firestore (`users/{uid}`)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return doc.data();
  }

  /// Updates personal profile for a user
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
    String? photoUrl,
  }) async {
    final nameError = validateFullName(name);
    if (nameError != null) throw nameError;

    final phoneError = validatePhone(phone);
    if (phoneError != null) throw phoneError;

    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    // 1. Update Firebase Auth display name if matching current user
    if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
      await _auth.currentUser!.updateDisplayName(trimmedName);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await _auth.currentUser!.updatePhotoURL(photoUrl);
      }
      await _auth.currentUser!.reload();
    }

    // 2. Update Firestore users collection
    final userUpdates = <String, dynamic>{
      'name': trimmedName,
      'phone': trimmedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null) {
      userUpdates['photoUrl'] = photoUrl;
    }

    await _firestore.collection('users').doc(uid).set(
          userUpdates,
          SetOptions(merge: true),
        );

    // 3. If driver document exists, keep driver name & phone synchronized
    final driverDoc = await _firestore.collection('drivers').doc(uid).get();
    if (driverDoc.exists) {
      await _firestore.collection('drivers').doc(uid).update({
        'name': trimmedName,
        'phone': trimmedPhone,
      });
    }
  }

  /// Updates driver vehicle & profile details
  Future<void> updateDriverProfile({
    required String uid,
    required String name,
    required String phone,
    required String vehicleType,
    required String vehicleNumber,
  }) async {
    final nameError = validateFullName(name);
    if (nameError != null) throw nameError;

    final phoneError = validatePhone(phone);
    if (phoneError != null) throw phoneError;

    final vehicleTypeError = validateVehicleType(vehicleType);
    if (vehicleTypeError != null) throw vehicleTypeError;

    final vehicleNumError = validateVehicleNumber(vehicleNumber);
    if (vehicleNumError != null) throw vehicleNumError;

    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final sanitizedType = vehicleType.trim().toLowerCase();
    final sanitizedNumber = vehicleNumber.trim().toUpperCase();

    // 1. Update Firebase Auth display name
    if (_auth.currentUser != null && _auth.currentUser!.uid == uid) {
      await _auth.currentUser!.updateDisplayName(trimmedName);
      await _auth.currentUser!.reload();
    }

    // 2. Update users collection
    await _firestore.collection('users').doc(uid).set({
      'name': trimmedName,
      'phone': trimmedPhone,
      'vehicleType': sanitizedType,
      'vehicleNumber': sanitizedNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Update drivers collection
    await _firestore.collection('drivers').doc(uid).set({
      'name': trimmedName,
      'phone': trimmedPhone,
      'vehicleType': sanitizedType,
      'vehicleNumber': sanitizedNumber,
    }, SetOptions(merge: true));
  }

  /// Sign Up with Email and Password with role provisioning
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String role = 'rider',
    String? phone,
    String? vehicleType,
    String? vehicleNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;

      // Update Firebase User Profile with Display Name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(fullName.trim());
        await credential.user!.reload();
      }

      if (uid != null) {
        final sanitizedRole = role.toLowerCase() == 'driver' ? 'driver' : 'rider';

        // 1. Authoritative user role record
        await _firestore.collection('users').doc(uid).set({
          'id': uid,
          'name': fullName.trim(),
          'email': email.trim(),
          'role': sanitizedRole,
          'phone': phone?.trim() ?? '',
          'vehicleType': vehicleType?.trim().toLowerCase() ?? 'bike',
          'vehicleNumber': vehicleNumber?.trim().toUpperCase() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. If Driver: provision official drivers/{uid} profile
        if (sanitizedRole == 'driver') {
          await _firestore.collection('drivers').doc(uid).set({
            'id': uid,
            'name': fullName.trim(),
            'phone': phone?.trim() ?? '',
            'vehicleType': vehicleType?.trim().toLowerCase() ?? 'bike',
            'vehicleNumber': vehicleNumber?.trim().toUpperCase() ?? 'ZYRO-${uid.substring(0, 4).toUpperCase()}',
            'isOnline': false,
            'isAvailable': false,
            'latitude': 0.0,
            'longitude': 0.0,
            'lastRideCompletedAt': null,
            'activeRideId': null,
          }, SetOptions(merge: true));
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('ZYRO Auth: signUpWithEmailPassword FirebaseAuthException [${e.code}]');
      throw getReadableAuthError(e);
    } catch (e) {
      debugPrint('ZYRO Auth: signUpWithEmailPassword Error: $e');
      throw 'Sign up failed: ${e.toString()}';
    }
  }

  /// Sign In with Email and Password
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('ZYRO Auth: signInWithEmailPassword FirebaseAuthException [${e.code}]');
      throw getReadableAuthError(e);
    } catch (e) {
      debugPrint('ZYRO Auth: signInWithEmailPassword Error: $e');
      throw 'Login failed: ${e.toString()}';
    }
  }

  /// Sign In / Sign Up with Google (Cross-Platform: Web Popup + Mobile Native)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        debugPrint('[GoogleAuth] Platform: Web');
        debugPrint('[GoogleAuth] Using Firebase signInWithPopup');

        // Web Platform: Strictly use Firebase Auth Popup (Zero google_sign_in_web dependency)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        debugPrint('[GoogleAuth] Platform: Native Mobile');
        debugPrint('[GoogleAuth] Using GoogleSignIn plugin');

        // Mobile Platform (Android / iOS): Use native GoogleSignIn
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          // The user canceled the sign-in flow
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // Provision or ensure user profile exists in Firestore
      final User? user = userCredential.user;
      if (user != null) {
        await _ensureUserProfileExists(user);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('ZYRO Google Auth FirebaseAuthException [${e.code}]: ${e.message}');
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        // Silent cancellation when user intentionally closes the popup
        return null;
      }
      throw getReadableAuthError(e);
    } catch (e) {
      debugPrint('ZYRO Google Auth Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('popup_closed_by_user') ||
          errorStr.contains('canceled') ||
          errorStr.contains('cancelled')) {
        return null;
      }
      throw 'Google Sign-In failed: ${e.toString()}';
    }
  }

  /// Ensures user profile exists in Firestore without allowing unauthorized privilege escalation
  Future<void> _ensureUserProfileExists(User user) async {
    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists || userDoc.data() == null) {
        // Check if this UID is already registered as a driver in drivers collection
        final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
        final String assignedRole = driverDoc.exists ? 'driver' : 'rider';

        await userDocRef.set({
          'id': user.uid,
          'name': (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!.trim()
              : 'ZYRO Rider',
          'email': user.email ?? '',
          'role': assignedRole,
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Warning: Failed to provision user profile: $e');
      // Do not block authentication if profile caching hits a non-fatal error
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      debugPrint('ZYRO Auth: sendPasswordResetEmail FirebaseAuthException [${e.code}]');
      throw getReadableAuthError(e);
    } catch (e) {
      debugPrint('ZYRO Auth: sendPasswordResetEmail Error: $e');
      throw 'Password reset failed: ${e.toString()}';
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await Future.wait([
          _auth.signOut(),
          _googleSignIn.signOut(),
        ]);
      }
    } catch (e) {
      debugPrint('ZYRO Auth: Sign out notice: $e');
      await _auth.signOut();
    }
  }

  /// Map Firebase Auth Exceptions to clean, friendly human messages
  static String getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'operation-not-allowed':
        return 'This sign-in provider is not enabled in Firebase Console. Please enable Google provider under Authentication > Sign-in method.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact ZYRO support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please verify and try again.';
      case 'invalid-credential':
        return 'Invalid email, password, or expired sign-in credential.';
      case 'too-many-requests':
        return 'Too many unsuccessful attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in provider. Please log in using that method.';
      case 'popup-closed-by-user':
        return 'Sign-in window was closed before completing authentication.';
      case 'cancelled-popup-request':
        return 'Authentication request was cancelled.';
      case 'popup-blocked':
        return 'The browser blocked the sign-in popup. Please allow popups for this site.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for OAuth in Firebase Console. Please add localhost/domain to Authorized Domains in Firebase Authentication Settings.';
      default:
        return e.message ?? 'An unexpected authentication error occurred (${e.code}).';
    }
  }
}


