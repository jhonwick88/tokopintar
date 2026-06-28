import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // --- WEB CONFIGURATION ---
  // Salin kredensial ini dari Firebase Console -> Project Settings -> General -> Web Apps
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCXFJk4ktbaTGErl_r2GCqWImnQ8k37UyM',
    appId: '1:259323413654:web:18568a9862ac4abe8b6eb7',
    messagingSenderId: '259323413654',
    projectId: 'tokopintarfc',
    authDomain: 'tokopintarfc.firebaseapp.com',
    storageBucket: 'tokopintarfc.firebasestorage.app',
  );

  // --- ANDROID CONFIGURATION ---
  // Salin dari google-services.json jika ingin inisialisasi eksplisit lewat opsi
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDwPlH7dX0hb4QoDHgYp49AfJG0AR4kg5g',
    appId: '1:259323413654:android:f34946e6422fee698b6eb7',
    messagingSenderId: '259323413654',
    projectId: 'tokopintarfc',
    storageBucket: 'tokopintarfc.firebasestorage.app',
  );

  // --- WINDOWS CONFIGURATION ---
  // Windows desktop dapat berbagi credential dengan Web app
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCXFJk4ktbaTGErl_r2GCqWImnQ8k37UyM',
    appId: '1:259323413654:web:18568a9862ac4abe8b6eb7',
    messagingSenderId: '259323413654',
    projectId: 'tokopintarfc',
    authDomain: 'tokopintarfc.firebaseapp.com',
    storageBucket: 'tokopintarfc.firebasestorage.app',
  );
}
