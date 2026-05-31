// PLACEHOLDER: Replace values using 'flutterfire configure' after setting up Firebase project
//
// TODO: Replace all placeholder values after creating your Firebase project.
// Steps: https://firebase.google.com/docs/flutter/setup
// Run: flutterfire configure (after installing FlutterFire CLI)
//   npm install -g firebase-tools
//   dart pub global activate flutterfire_cli
//   flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Whether Firebase has been configured with real credentials.
/// All platforms' apiKey fields are empty in placeholder mode.
bool get _firebaseNotConfigured =>
    DefaultFirebaseOptions.currentPlatform.apiKey.isEmpty;

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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // -------------------------------------------------------------------------
  // TODO: Replace every empty string below with real values from Firebase
  //       Console → Project Settings → Your apps → google-services.json /
  //       GoogleService-Info.plist, or run `flutterfire configure`.
  // -------------------------------------------------------------------------

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '', // TODO: replace
    appId: '', // TODO: replace  e.g. '1:1234567890:web:abc123'
    messagingSenderId: '', // TODO: replace  e.g. '1234567890'
    projectId: '', // TODO: replace  e.g. 'my-project-id'
    authDomain: '', // TODO: replace  e.g. 'my-project.firebaseapp.com'
    storageBucket: '', // TODO: replace  e.g. 'my-project.appspot.com'
    measurementId: '', // TODO: replace  e.g. 'G-XXXXXXXXXX'
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '', // TODO: replace
    appId: '', // TODO: replace  e.g. '1:1234567890:android:abc123'
    messagingSenderId: '', // TODO: replace
    projectId: '', // TODO: replace
    storageBucket: '', // TODO: replace
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '', // TODO: replace
    appId: '', // TODO: replace  e.g. '1:1234567890:ios:abc123'
    messagingSenderId: '', // TODO: replace
    projectId: '', // TODO: replace
    storageBucket: '', // TODO: replace
    iosBundleId: '', // TODO: replace  e.g. 'com.example.passengerApp'
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: '', // TODO: replace
    appId: '', // TODO: replace
    messagingSenderId: '', // TODO: replace
    projectId: '', // TODO: replace
    storageBucket: '', // TODO: replace
    iosBundleId: '', // TODO: replace
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: '', // TODO: replace
    appId: '', // TODO: replace
    messagingSenderId: '', // TODO: replace
    projectId: '', // TODO: replace
    authDomain: '', // TODO: replace
    storageBucket: '', // TODO: replace
    measurementId: '', // TODO: replace
  );
}

/// Returns true when all credential fields are still empty placeholders.
/// Use this guard before calling Firebase.initializeApp().
bool get firebaseNotConfigured => _firebaseNotConfigured;
