import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'wedit';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Supabase
  static const String supabaseUrl = 'https://oyearthvuorctyoyoknf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_c-OIUVRVoaADF7qAo3QgJA_9ValKuJS';

  // Google Maps
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Chapa Payment
  static const String chapaPublicKey = 'YOUR_CHAPA_PUBLIC_KEY';
  static const String chapaBaseUrl = 'https://api.chapa.co/v1';

  // Telebirr Payment
  static const String telebirrAppId = 'YOUR_TELEBIRR_APP_ID';
  static const String telebirrBaseUrl = 'https://checkout.telebirr.com';

  // Addis Ababa center coordinates
  static const double addisAbabaLat = 9.0350;
  static const double addisAbabaLng = 38.7516;
  static const double defaultZoom = 13.0;
  static const double nearbyRadius = 5000.0; // meters

  // Ride
  static const int rideRequestTimeoutSecs = 300; // 5 minutes
  static const int offerExpiryDefaultSecs = 30;
  static const int driverSearchRadiusMeters = 5000;
  static const double cancellationFeeEtb = 20.0;

  // Base fares per vehicle type (ETB)
  static const double baseFareSedan = 50.0;
  static const double basefareSuv = 75.0;
  static const double baseFareVip = 120.0;
  static const double baseFareMinibus = 40.0;
  static const double pricePerKmSedan = 12.0;
  static const double pricePerKmSuv = 18.0;
  static const double pricePerKmVip = 25.0;
  static const double pricePerKmMinibus = 10.0;

  // Loyalty Points
  static const int pointsPerRide = 10;
  static const int pointsPerReferral = 50;
  static const int pointsRedemptionDiscountThreshold = 100;
  static const int pointsRedemptionFreeRideThreshold = 500;
  static const double pointsDiscountPercentage = 0.20; // 20%
  static const double pointsToEtbRate = 0.20; // 1 point = 0.20 ETB

  // Subscription prices (ETB/month)
  static const double subscriptionPriceBasic = 99.0;
  static const double subscriptionPricePremium = 199.0;

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('am'),
    Locale('om'),
    Locale('ti'),
    Locale('so'),
  ];

  // Language names for display
  static const Map<String, String> languageNames = {
    'en': 'English',
    'ar': 'العربية',
    'am': 'አማርኛ',
    'om': 'Afaan Oromoo',
    'ti': 'ትግርኛ',
    'so': 'Soomaali',
  };

  // Vehicle types
  static const List<String> vehicleTypes = ['sedan', 'suv', 'vip', 'minibus'];

  // Payment methods
  static const List<String> paymentMethods = [
    'cash',
    'chapa',
    'telebirr',
    'bank_transfer',
  ];

  // Ride status values
  static const String rideStatusPending = 'pending';
  static const String rideStatusAccepted = 'accepted';
  static const String rideStatusArriving = 'arriving';
  static const String rideStatusStarted = 'started';
  static const String rideStatusCompleted = 'completed';
  static const String rideStatusCancelled = 'cancelled';

  // Cancellation reasons
  static const List<String> cancellationReasons = [
    'Driver is late',
    'Changed my mind',
    'Wrong location set',
    'Found another ride',
    'Emergency',
    'Other',
  ];

  // Raffle
  static const int raffleMinRides = 10;
  static const int raffleWeeklyPrize1Etb = 500;
  static const int raffleWeeklyPrize2Etb = 300;
  static const int raffleWeeklyPrize3Etb = 200;

  // SharedPreferences keys
  static const String prefKeyOnboardingShown = 'onboarding_shown';
  static const String prefKeySelectedLanguage = 'selected_language';
  static const String prefKeyUserId = 'user_id';
  static const String prefKeyThemeMode = 'theme_mode';

  // Hive box names
  static const String hiveBoxRideHistory = 'ride_history';
  static const String hiveBoxNotifications = 'notifications';

  // Firebase topics
  static const String fcmTopicGeneral = 'general';
  static const String fcmTopicPromotions = 'promotions';
}
