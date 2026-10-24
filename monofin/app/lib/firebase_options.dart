// Firebase settings for Android.
//
// The GitHub workflow overwrites this file using the GOOGLE_SERVICES_JSON
// secret (see tool/gen_firebase_options.py), so you normally never edit it.
// To build on your own computer instead, copy the values from
// google-services.json:
//   apiKey            -> client[0].api_key[0].current_key
//   appId             -> client[0].client_info.mobilesdk_app_id
//   messagingSenderId -> project_info.project_number
//   projectId         -> project_info.project_id
//   storageBucket     -> project_info.storage_bucket
// While apiKey is empty the app runs normally, just without push notifications.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static const bool isConfigured = false;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
    storageBucket: '',
  );
}
