// File generated based on Firebase project configuration.
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCOOhNxFAjCsckZ5OWUkKulL7vyp8lUSD4',
    authDomain: 'etiquetas-4ef97.firebaseapp.com',
    projectId: 'etiquetas-4ef97',
    storageBucket: 'etiquetas-4ef97.firebasestorage.app',
    messagingSenderId: '233947787024',
    appId: '1:233947787024:web:50acc5eb0847e0ff74ff95',
    measurementId: 'G-Z2R6YDQC7Q',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBscDJlmgg_nQLx3v9RSiIXqu7hy8bTfGI',
    appId: '1:233947787024:android:b89d64f34bc17a4674ff95',
    messagingSenderId: '233947787024',
    projectId: 'etiquetas-4ef97',
    storageBucket: 'etiquetas-4ef97.firebasestorage.app',
  );
}
