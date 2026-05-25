class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'wedit';
  static const String appVersion = '1.0.0';

  // Supabase
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Tables
  static const String driversTable = 'drivers';
  static const String ridesTable = 'rides';
  static const String rideRequestsTable = 'ride_requests';
  static const String subscriptionsTable = 'driver_subscriptions';
  static const String earningsTable = 'driver_earnings';
  static const String competitionRankingsTable = 'competition_rankings';
  static const String competitionSettingsTable = 'competition_settings';
  static const String competitionWinnersTable = 'competition_winners';
  static const String usersTable = 'users';
  static const String notificationsTable = 'notifications';

  // Storage buckets
  static const String documentsBucket = 'driver-documents';
  static const String receiptsBucket = 'payment-receipts';
  static const String avatarsBucket = 'avatars';

  // SharedPreferences keys
  static const String prefLocale = 'locale';
  static const String prefDriverId = 'driver_id';
  static const String prefOnlineStatus = 'online_status';
  static const String prefPreferredDest = 'preferred_destination';

  // Map defaults (Addis Ababa)
  static const double defaultLat = 9.0246;
  static const double defaultLng = 38.7468;
  static const double defaultZoom = 13.0;

  // Ride request timeout
  static const int rideRequestTimeoutSeconds = 30;

  // Location update interval
  static const int locationUpdateIntervalSeconds = 10;

  // Subscription prices (ETB)
  static const double dailyPrice = 50.0;
  static const double weeklyPrice = 300.0;
  static const double monthlyPrice = 1000.0;

  // Bank info
  static const String bankName = 'Commercial Bank of Ethiopia';
  static const String bankAccount = '1000123456789';
  static const String bankHolder = 'wedit Technologies PLC';

  // Leaderboard
  static const int leaderboardTopN = 50;
  static const int raffleRequiredRides = 25;
  static const int raffleRequiredInvites = 5;

  // Vehicle types
  static const List<String> vehicleTypes = ['sedan', 'suv', 'minibus'];

  // Rating
  static const double minRating = 1.0;
  static const double maxRating = 5.0;

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 60;

  // Registration steps count
  static const int registrationSteps = 5;
}
