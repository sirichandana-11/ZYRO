import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

  /// Real-time stream of the authoritative user role from Firestore (`users/{uid}`)
  /// Returns "rider", "driver", or null if the user doc/role is missing.
  Stream<String?> watchUserRole(String uid) {
    if (uid.isEmpty) return Stream.value(null);

    debugPrint('[ROLE] watchUserRole UID: $uid');
    debugPrint('[ROLE] Firestore path: users/$uid');

    // Diagnosis one-time get()
    _firestore.collection('users').doc(uid).get().then((doc) {
      debugPrint('[ROLE GET] exists: ${doc.exists}');
      debugPrint('[ROLE GET] data: ${doc.data()}');
    }).catchError((e, stackTrace) {
      debugPrint('[ROLE GET ERROR] $e');
      debugPrint('[ROLE GET STACK] $stackTrace');
    });

    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      debugPrint('[ROLE] Firestore snapshot received');
      debugPrint('[ROLE] exists: ${snapshot.exists}');
      debugPrint('[ROLE] data: ${snapshot.data()}');

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final rawRole = data['role'] as String?;
        if (rawRole != null && rawRole.trim().isNotEmpty) {
          final normalized = rawRole.trim().toLowerCase();
          if (normalized == 'driver') {
            debugPrint('[AUTH] Role verification successful: driver');
            return 'driver';
          } else if (normalized == 'rider') {
            debugPrint('[AUTH] Role verification successful: rider');
            return 'rider';
          }
          return normalized;
        }
      }

      debugPrint('[AUTH] Role: null (users/$uid not found or role empty)');
      return null;
    });
  }

  /// Fetches authoritative user role from Firestore (`users/{uid}`)
  /// Returns "rider", "driver", or null if the user doc/role is missing.
  Future<String?> getUserRole(String uid) async {
    if (uid.isEmpty) return null;
    debugPrint('[AUTH] Reading users/$uid');
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      debugPrint('[AUTH] Firestore document exists: ${userDoc.exists}');
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        debugPrint('[AUTH] Firestore data: $data');
        final rawRole = data['role'] as String?;
        debugPrint('[AUTH] Role: $rawRole');
        if (rawRole != null && rawRole.trim().isNotEmpty) {
          return rawRole.trim().toLowerCase();
        }
      }
      return null;
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] FirebaseException in getUserRole for users/$uid: [${e.code}] ${e.message}');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Unexpected error in getUserRole for users/$uid: $e');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sets or completes the authoritative user role in Firestore (`users/{uid}`)
  /// SECURITY: Role is immutable. If a role is already assigned, this method
  /// will throw an error instead of overwriting.
  Future<void> setUserRole(String uid, String role) async {
    if (uid.isEmpty) return;
    final sanitizedRole = role.toLowerCase().trim() == 'driver' ? 'driver' : 'rider';

    // SECURITY CHECK: Reject if user already has a role assigned
    try {
      final existingDoc = await _firestore.collection('users').doc(uid).get();
      if (existingDoc.exists && existingDoc.data() != null) {
        final existingRole = existingDoc.data()!['role'] as String?;
        if (existingRole != null && existingRole.trim().isNotEmpty) {
          final normalizedExisting = existingRole.trim().toLowerCase();
          if (normalizedExisting != sanitizedRole) {
            throw 'This account is already registered as a ${normalizedExisting == 'driver' ? 'Driver' : 'Rider'}. Role cannot be changed.';
          }
          debugPrint('[AUTH] setUserRole: role already set to $normalizedExisting, no change needed.');
          return;
        }
      }
    } catch (e) {
      if (e is String) rethrow;
      debugPrint('[AUTH ERROR] setUserRole check error: $e');
      throw 'Unable to verify account status. Please check your connection and try again.';
    }

    await _firestore.collection('users').doc(uid).set({
      'id': uid,
      'role': sanitizedRole,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (sanitizedRole == 'driver') {
      try {
        final driverDoc = await _firestore.collection('drivers').doc(uid).get();
        if (!driverDoc.exists) {
          final subUid = uid.length >= 4 ? uid.substring(0, 4).toUpperCase() : uid.toUpperCase();
          await _firestore.collection('drivers').doc(uid).set({
            'id': uid,
            'name': currentUser?.displayName ?? 'ZYRO Driver',
            'phone': '',
            'vehicleType': 'bike',
            'vehicleNumber': 'ZYRO-$subUid',
            'isOnline': false,
            'isAvailable': false,
            'latitude': 0.0,
            'longitude': 0.0,
            'lastRideCompletedAt': null,
            'activeRideId': null,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('[AUTH ERROR] Error provisioning driver record: $e');
      }
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

  /// Sign Up with Email and Password with role provisioning.
  /// Creates the Firestore users/{uid} document with the role immediately.
  /// After signup, AuthGate routes directly to the correct dashboard.
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String role = 'rider',
    String? phone,
    String? vehicleType,
    String? vehicleNumber,
  }) async {
    final sanitizedRole = role.toLowerCase().trim() == 'driver' ? 'driver' : 'rider';
    debugPrint('[AUTH] Signup started');
    debugPrint('[AUTH] Email: ${email.trim()}');
    debugPrint('[AUTH] Full Name: ${fullName.trim()}');
    debugPrint('[AUTH] Selected role: $sanitizedRole');

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User is null after signup');
      }

      debugPrint('[FIREBASE] PROJECT: ${Firebase.app().options.projectId}');
      debugPrint('[FIRESTORE] START WRITE');
      debugPrint('[FIRESTORE] UID: ${user.uid}');
      debugPrint('[FIRESTORE] ROLE: $sanitizedRole');

      final profileData = sanitizedRole == 'driver'
          ? <String, dynamic>{
              'email': user.email,
              'name': fullName.trim(),
              'role': 'driver',
              'createdAt': FieldValue.serverTimestamp(),
            }
          : <String, dynamic>{
              'email': user.email,
              'name': fullName.trim(),
              'role': 'rider',
              'createdAt': FieldValue.serverTimestamp(),
            };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profileData);

      debugPrint('[FIRESTORE] WRITE SUCCESS');

      if (sanitizedRole == 'driver') {
        final subUid = user.uid.length >= 4 ? user.uid.substring(0, 4).toUpperCase() : user.uid.toUpperCase();
        await _firestore.collection('drivers').doc(user.uid).set({
          'id': user.uid,
          'name': fullName.trim(),
          'phone': phone?.trim() ?? '',
          'vehicleType': vehicleType?.trim().toLowerCase() ?? 'bike',
          'vehicleNumber': vehicleNumber?.trim().toUpperCase() ?? 'ZYRO-$subUid',
          'isOnline': false,
          'isAvailable': false,
          'latitude': 0.0,
          'longitude': 0.0,
          'lastRideCompletedAt': null,
          'activeRideId': null,
        }, SetOptions(merge: true));
      }

      // Immediate verification
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      debugPrint('[FIRESTORE] EXISTS: ${doc.exists}');
      debugPrint('[FIRESTORE] DATA: ${doc.data()}');

      if (!doc.exists) {
        throw Exception('Firestore profile creation failed: users/${user.uid} was not found.');
      }

      final storedRole = doc.data()?['role'] as String?;
      if (storedRole == null || storedRole.isEmpty) {
        throw Exception('Firestore profile creation failed: role is missing in users/${user.uid}.');
      }

      debugPrint('[AUTH] Role verification successful');
      debugPrint('[AUTH] Navigating to ${sanitizedRole == 'driver' ? 'Driver Dashboard' : 'Rider Dashboard'}');

      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] signUpWithEmailPassword FirebaseAuthException [${e.code}]: ${e.message}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      throw getReadableAuthError(e);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] signUpWithEmailPassword FirebaseException [${e.code}]: ${e.message}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      throw 'Firestore Error [${e.code}]: ${e.message ?? e.toString()}';
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] signUpWithEmailPassword Error: $e');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sign In with Email and Password with authoritative role validation
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
    String? expectedRole,
  }) async {
    final selectedRole = expectedRole?.toLowerCase().trim();
    debugPrint('[AUTH] Login started');
    debugPrint('[AUTH] Email: ${email.trim()}');
    debugPrint('[AUTH] Selected role: $selectedRole');

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw 'Firebase Authentication succeeded but user is null.';
      }

      final uid = user.uid;
      debugPrint('[AUTH] Firebase authentication successful');
      debugPrint('[AUTH] UID: $uid');

      final storedRole = await getUserRole(uid);
      final normalizedStored = storedRole?.toLowerCase().trim();

      debugPrint('[AUTH] Stored role: $normalizedStored');
      debugPrint('[AUTH] Selected role: $selectedRole');

      if (normalizedStored != null && normalizedStored.isNotEmpty) {
        if (selectedRole != null && selectedRole.isNotEmpty) {
          if (normalizedStored != selectedRole) {
            debugPrint('[AUTH] Role mismatch: stored=$normalizedStored vs selected=$selectedRole. Signing out.');
            await signOut();

            if (normalizedStored == 'rider') {
              throw 'This email is registered as a Rider account. Please use Rider login.';
            } else if (normalizedStored == 'driver') {
              throw 'This email is registered as a Driver account. Please use Driver login.';
            } else {
              throw 'This account has an incompatible role ($normalizedStored).';
            }
          }
        }
        debugPrint('[AUTH] Role verification successful');
        debugPrint('[AUTH] Navigating to ${normalizedStored == 'driver' ? 'Driver Dashboard' : 'Rider Dashboard'}');
      } else {
        debugPrint('[AUTH] No Firestore role found for UID $uid. Signing out.');
        await signOut();
        throw 'User profile is missing. Please create a new account.';
      }

      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] signInWithEmailPassword FirebaseAuthException [${e.code}]: ${e.message}');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      throw getReadableAuthError(e);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] signInWithEmailPassword FirebaseException [${e.code}]: ${e.message}');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      if (e.code == 'permission-denied') {
        throw 'Firestore permission denied. Please verify Firestore rules in Firebase Console.';
      }
      throw 'Database error (${e.code}): ${e.message ?? e.toString()}';
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] signInWithEmailPassword Error: $e');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sign In / Sign Up with Google (Cross-Platform: Web Popup + Mobile Native) with role validation
  Future<UserCredential?> signInWithGoogle({String? expectedRole}) async {
    final selectedRole = expectedRole?.toLowerCase().trim();
    debugPrint('[AUTH] Google sign-in started');
    debugPrint('[AUTH] Selected role: $selectedRole');

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        debugPrint('[GoogleAuth] Platform: Web');
        debugPrint('[GoogleAuth] Using Firebase signInWithPopup');

        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        debugPrint('[GoogleAuth] Platform: Native Mobile');
        debugPrint('[GoogleAuth] Using GoogleSignIn plugin');

        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          debugPrint('[GoogleAuth] User cancelled Google Sign-In');
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

      final User? user = userCredential.user;
      if (user != null) {
        debugPrint('[AUTH] Firebase authentication successful');
        debugPrint('[AUTH] UID: ${user.uid}');

        final storedRole = await getUserRole(user.uid);
        final normalizedStored = storedRole?.toLowerCase().trim();

        debugPrint('[AUTH] Stored role: $normalizedStored');
        debugPrint('[AUTH] Selected role: $selectedRole');

        if (normalizedStored != null && normalizedStored.isNotEmpty) {
          if (selectedRole != null && selectedRole.isNotEmpty) {
            if (normalizedStored != selectedRole) {
              debugPrint('[AUTH] Role mismatch: stored=$normalizedStored vs selected=$selectedRole. Signing out.');
              await signOut();
              if (normalizedStored == 'rider') {
                throw 'This email is registered as a Rider account. Please use Rider login.';
              } else if (normalizedStored == 'driver') {
                throw 'This email is registered as a Driver account. Please use Driver login.';
              } else {
                throw 'This account has an incompatible role ($normalizedStored).';
              }
            }
          }
          debugPrint('[AUTH] Role verification successful');
          debugPrint('[AUTH] Navigating to ${normalizedStored == 'driver' ? 'Driver Dashboard' : 'Rider Dashboard'}');
        } else {
          debugPrint('[AUTH] No Firestore role found for Google user UID ${user.uid}. Signing out.');
          await signOut();
          throw 'User profile is missing. Please create a new account.';
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Google Auth FirebaseAuthException [${e.code}]: ${e.message}');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return null;
      }
      throw getReadableAuthError(e);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Google Auth FirebaseException [${e.code}]: ${e.message}');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      if (e.code == 'permission-denied') {
        throw 'Firestore permission denied. Please verify Firestore rules in Firebase Console.';
      }
      throw 'Database error (${e.code}): ${e.message ?? e.toString()}';
    } catch (e, stackTrace) {
      debugPrint('[AUTH ERROR] Google Auth Error: $e');
      debugPrint('[AUTH ERROR] ${e.runtimeType}');
      debugPrint('[AUTH ERROR] Stack trace: $stackTrace');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('popup_closed_by_user') ||
          errorStr.contains('canceled') ||
          errorStr.contains('cancelled')) {
        return null;
      }
      rethrow;
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
