class AppConstants {
  AppConstants._();

  // Supabase — replace with your real values
  static const String supabaseUrl     = 'https://oyearthvuorctyoyoknf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_c-OIUVRVoaADF7qAo3QgJA_9ValKuJS';

  // Google Maps (used in dashboard live-map)
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Addis Ababa center
  static const double addisAbabaLat = 9.0350;
  static const double addisAbabaLng = 38.7516;
  static const double defaultZoom   = 12.0;

  // Pagination
  static const int defaultPageSize = 25;

  // Vehicle types
  static const List<String> vehicleTypes = ['sedan', 'suv', 'vip', 'minibus'];

  // Subscription plans
  static const Map<String, double> subscriptionPrices = {
    'daily':   50.0,
    'weekly':  300.0,
    'monthly': 1000.0,
  };

  // Base fares (ETB)
  static const Map<String, double> baseFares = {
    'sedan':   25.0,
    'suv':     35.0,
    'vip':     60.0,
    'minibus': 20.0,
  };

  // Price per km (ETB)
  static const Map<String, double> pricePerKm = {
    'sedan':   8.0,
    'suv':     12.0,
    'vip':     20.0,
    'minibus': 6.0,
  };

  // Points rules
  static const int    pointsPerRide              = 10;
  static const int    holidayPointsMultiplier    = 2;
  static const double electronicPaymentBonusPct  = 0.05;  // 5%
  static const int    pointsForDiscount          = 100;
  static const double discountPercentage         = 0.20;
  static const double maxDiscountEtb             = 50.0;
  static const int    pointsForFreeRide          = 500;
  static const double maxFreeRideEtb             = 150.0;

  // Referral rewards
  static const int referrerPassengerPoints = 50;
  static const int referredPassengerPoints = 20;

  // App info
  static const String appName    = 'wedit Admin';
  static const String appVersion = '1.0.0';
}
