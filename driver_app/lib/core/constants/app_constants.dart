class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'wedit';
  static const String appVersion = '1.0.0';

  // Supabase
  static const String supabaseUrl = 'https://oyearthvuorctyoyoknf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_c-OIUVRVoaADF7qAo3QgJA_9ValKuJS';

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
  // Fleet: idle updates every 30s to save battery; 5s during active ride
  static const int locationUpdateIdleSeconds = 30;
  static const int locationUpdateRideSeconds = 5;

  // Fleet owner tables
  static const String fleetVehiclesTable = 'fleet_vehicles';
  static const String fleetAssignmentsTable = 'fleet_driver_assignments';
  static const String fleetSettlementsTable = 'fleet_settlements';
  static const String fleetTermsVersion = '1.0';

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
