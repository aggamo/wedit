import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/di/injection.dart';
import 'firebase_options.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Top-level FCM background/terminated message handler.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised before any Firebase calls in the isolate.
  if (!firebaseNotConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('FCM background message: ${message.messageId}');
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _setupFcm() async {
  // Request permission (iOS / Android 13+).
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Print the FCM token so it can be copied during development.
  final token = await messaging.getToken();
  debugPrint('FCM token (passenger): $token');

  // Register the background handler.
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // --- Local notifications setup (for foreground display) ---
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await _localNotifications.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  // Create the Android notification channel.
  const channel = AndroidNotificationChannel(
    'wedit_rides', // id
    'رحلات', // name (Arabic: "Rides")
    importance: Importance.high,
    enableVibration: true,
  );
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Foreground message handler – show a local notification.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: channel.importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
    debugPrint('FCM foreground message: ${message.messageId}');
  });

  // Listen for token refresh.
  messaging.onTokenRefresh.listen((newToken) {
    debugPrint('FCM token refreshed (passenger): $newToken');
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Firebase init (graceful fail if not configured)
  try {
    if (firebaseNotConfigured) {
      debugPrint(
        'Firebase init skipped: firebase_options.dart contains placeholder '
        'values. Run `flutterfire configure` to set up Firebase.',
      );
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _setupFcm();
    }
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  await configureDependencies();

  runApp(const ProviderScope(child: WeditPassengerApp()));
}

class WeditPassengerApp extends ConsumerWidget {
  const WeditPassengerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'wedit',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConstants.supportedLocales,
      locale: const Locale('ar'),
    );
  }
}
