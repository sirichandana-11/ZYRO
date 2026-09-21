import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  // REAL WEB CONFIG
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAA1h-opqqN1skaUlmzBQdq5IuWYG7IsD4',
    appId: '1:71643803148:web:f872aaa1b283cb96ae8829',
    messagingSenderId: '71643803148',
    projectId: 'zyro-66077',
    authDomain: 'zyro-66077.firebaseapp.com',
    storageBucket: 'zyro-66077.firebasestorage.app',
  );

  // Keep these unchanged for now
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyZYRO-AppKeyExamplePlaceholder000',
    appId: '1:100000000000:android:zyro000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'zyro-rides',
    storageBucket: 'zyro-rides.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyZYRO-AppKeyExamplePlaceholder000',
    appId: '1:100000000000:ios:zyro000000000000000000',
    messagingSenderId: '100000000000',
    projectId: 'zyro-rides',
    storageBucket: 'zyro-rides.appspot.com',
    iosBundleId: 'com.zyro.zyro',
  );
}