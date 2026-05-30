import '../../domain/entities/driver_entity.dart';

class DriverModel extends DriverEntity {
  const DriverModel({
    required super.id,
    required super.phone,
    super.name,
    super.email,
    super.avatarUrl,
    super.status,
    super.rating,
    super.totalRides,
    super.referralCode,
    super.referredBy,
    required super.createdAt,
    super.hasActiveSubscription,
    super.fcmToken,
    super.role,
    super.isFleetOwner,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalRides: json['total_rides'] as int? ?? 0,
      referralCode: json['referral_code'] as String?,
      referredBy: json['referred_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
      fcmToken: json['fcm_token'] as String?,
      role: json['role'] as String? ?? 'driver',
      isFleetOwner: (json['role'] as String?) == 'fleet_owner',
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
      'rating': rating,
      'total_rides': totalRides,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'created_at': createdAt.toIso8601String(),
      'has_active_subscription': hasActiveSubscription,
      'fcm_token': fcmToken,
      'role': role,
    };
  }
}
