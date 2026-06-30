import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores a pending navigation route produced by a notification tap so the
/// router can consume it once it is ready.
String? _pendingRoute;

/// Returns and clears the route that a notification tap requested.
String? consumePendingRoute() {
  final route = _pendingRoute;
  _pendingRoute = null;
  return route;
}

/// Top-level FCM background/terminated message handler.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FcmService] Background message: ${message.messageId}');
  // Heavy work (DB writes, etc.) should be deferred until the app comes to
  // the foreground to avoid battery / wake-lock issues on Android.
}

/// Singleton service that wires up Firebase Cloud Messaging for the driver app.
class FcmService {
  FcmService._();

  static const String _channelId = 'wedit_rides';
  static const String _channelName = 'رحلات'; // Arabic: "Rides"

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    importance: Importance.high,
    enableVibration: true,
  );

  /// Call once from main() after Firebase.initializeApp().
  ///
  /// [supabase] is used to persist the FCM token to the `profiles` table so
  /// the backend can target this device for push notifications.
  static Future<void> initialize(SupabaseClient supabase) async {
    final messaging = FirebaseMessaging.instance;

    // 1. Request permission (iOS / Android 13+).
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      '[FcmService] Notification permission: ${settings.authorizationStatus}',
    );

    // 2. Get the current token and save it to Supabase.
    final token = await messaging.getToken();
    if (token != null) {
      debugPrint('[FcmService] FCM token (driver): $token');
      await _saveTokenToSupabase(supabase, token);
    }

    // 3. Refresh token handler.
    messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FcmService] FCM token refreshed (driver): $newToken');
      await _saveTokenToSupabase(supabase, newToken);
    });

    // 4. Register the background / terminated handler.
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

    // 5. Set up flutter_local_notifications (for foreground display).
    await _initLocalNotifications();

    // 6. Foreground message handler.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 7. Notification-tap handler when app is in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 8. Check if the app was launched from a terminated-state notification.
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Upserts [token] into the `profiles.fcm_token` column for the signed-in user.
  static Future<void> _saveTokenToSupabase(
    SupabaseClient supabase,
    String token,
  ) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('[FcmService] Skipping token save – user not signed in.');
        return;
      }
      await supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('[FcmService] FCM token saved to profiles.');
    } catch (e) {
      debugPrint('[FcmService] Failed to save FCM token: $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // User tapped a local notification while app was in foreground.
        if (response.payload != null && response.payload!.isNotEmpty) {
          _pendingRoute = response.payload;
          debugPrint('[FcmService] Notification tap → route: $_pendingRoute');
        }
      },
    );

    // Create the Android notification channel.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Extract a navigation route from the data payload if present.
    final route = message.data['route'] as String?;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          importance: _channel.importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: route,
    );

    debugPrint('[FcmService] Foreground message shown: ${message.messageId}');
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && route.isNotEmpty) {
      _pendingRoute = route;
      debugPrint('[FcmService] Notification tap → pending route: $route');
    }
  }
}
