class DriverEntity {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String status; // pending, approved, rejected, suspended
  final String role;   // driver, fleet_owner
  final double rating;
  final int totalRides;
  final String? referralCode;
  final String? referredBy;
  final DateTime createdAt;
  final bool hasActiveSubscription;
  final String? fcmToken;
  // Fleet driver fields (set when this driver belongs to a fleet)
  final String? fleetOwnerId;
  final bool isCarActive;
  final bool surgeEnabled;
  final int? maxDailyTrips;
  final int dailyTripsCount;

  const DriverEntity({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.avatarUrl,
    this.status = 'pending',
    this.role = 'driver',
    this.rating = 5.0,
    this.totalRides = 0,
    this.referralCode,
    this.referredBy,
    required this.createdAt,
    this.hasActiveSubscription = false,
    this.fcmToken,
    this.fleetOwnerId,
    this.isCarActive = true,
    this.surgeEnabled = false,
    this.maxDailyTrips,
    this.dailyTripsCount = 0,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved' || status == 'active';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';
  bool get isRegistrationComplete => name != null && name!.isNotEmpty;
  bool get isFleetOwner => role == 'fleet_owner';
  bool get isFleetDriver => fleetOwnerId != null;
  bool get hasReachedDailyLimit =>
      maxDailyTrips != null && dailyTripsCount >= maxDailyTrips!;

  DriverEntity copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? avatarUrl,
    String? status,
    String? role,
    double? rating,
    int? totalRides,
    String? referralCode,
    String? referredBy,
    DateTime? createdAt,
    bool? hasActiveSubscription,
    String? fcmToken,
    String? fleetOwnerId,
    bool? isCarActive,
    bool? surgeEnabled,
    int? maxDailyTrips,
    int? dailyTripsCount,
  }) {
    return DriverEntity(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      role: role ?? this.role,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      createdAt: createdAt ?? this.createdAt,
      hasActiveSubscription:
          hasActiveSubscription ?? this.hasActiveSubscription,
      fcmToken: fcmToken ?? this.fcmToken,
      fleetOwnerId: fleetOwnerId ?? this.fleetOwnerId,
      isCarActive: isCarActive ?? this.isCarActive,
      surgeEnabled: surgeEnabled ?? this.surgeEnabled,
      maxDailyTrips: maxDailyTrips ?? this.maxDailyTrips,
      dailyTripsCount: dailyTripsCount ?? this.dailyTripsCount,
    );
  }
}
