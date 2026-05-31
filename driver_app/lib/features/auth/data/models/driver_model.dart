import '../../domain/entities/driver_entity.dart';

class DriverModel extends DriverEntity {
  const DriverModel({
    required super.id,
    required super.phone,
    super.name,
    super.email,
    super.avatarUrl,
    super.status,
    super.role,
    super.rating,
    super.totalRides,
    super.referralCode,
    super.referredBy,
    required super.createdAt,
    super.hasActiveSubscription,
    super.fcmToken,
    super.fleetOwnerId,
    super.isCarActive,
    super.surgeEnabled,
    super.maxDailyTrips,
    super.dailyTripsCount,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      role: json['role'] as String? ?? 'driver',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRides: json['total_rides'] as int? ?? 0,
      referralCode: json['referral_code'] as String?,
      referredBy: json['referred_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
      fcmToken: json['fcm_token'] as String?,
      fleetOwnerId: json['fleet_owner_id'] as String?,
      isCarActive: json['is_car_active'] as bool? ?? true,
      surgeEnabled: json['surge_enabled'] as bool? ?? false,
      maxDailyTrips: json['max_daily_trips'] as int?,
      dailyTripsCount: json['daily_trips_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'status': status,
      'role': role,
      'rating': rating,
      'total_rides': totalRides,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'created_at': createdAt.toIso8601String(),
      'has_active_subscription': hasActiveSubscription,
      'fcm_token': fcmToken,
      'fleet_owner_id': fleetOwnerId,
      'is_car_active': isCarActive,
      'surge_enabled': surgeEnabled,
      'max_daily_trips': maxDailyTrips,
      'daily_trips_count': dailyTripsCount,
    };
  }
}
