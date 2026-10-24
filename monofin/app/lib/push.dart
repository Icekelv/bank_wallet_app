import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

typedef PushHandler = void Function(Map<String, dynamic> data, String? title, String? body, bool openedFromTray);

/// Firebase Cloud Messaging. Messages with a notification block are shown by
/// Android automatically while the app is in the background; while it is open
/// they arrive here and the app shows them as a banner. Data-only messages of
/// type "config" tell the app the admin switched Bank/Wallet mode.
class Push {
  bool enabled = false;
  String? token;
  PushHandler? _onMessage;
  Future<void> Function(String token)? _onToken;

  Future<void> init({required PushHandler onMessage, required Future<void> Function(String) onToken}) async {
    _onMessage = onMessage;
    _onToken = onToken;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('Push disabled: firebase_options.dart has no values.');
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      }
      enabled = true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return;
    }

    final fm = FirebaseMessaging.instance;
    FirebaseMessaging.onMessage.listen((m) {
      _onMessage?.call(m.data, m.notification?.title, m.notification?.body, false);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _onMessage?.call(m.data, m.notification?.title, m.notification?.body, true);
    });
    fm.onTokenRefresh.listen((t) {
      token = t;
      _onToken?.call(t);
    });
    try {
      final initial = await fm.getInitialMessage();
      if (initial != null) {
        _onMessage?.call(initial.data, initial.notification?.title, initial.notification?.body, true);
      }
    } catch (_) {}
  }

  /// Asks for permission (Android 13+), uploads the device token and joins
  /// the "all" topic used for broadcasts and mode switches.
  Future<void> registerDevice() async {
    if (!enabled) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
      await fm.subscribeToTopic('all');
      token = await fm.getToken();
      if (token != null) await _onToken?.call(token!);
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }
}
