import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phone,
    super.fullName,
    super.role,
    super.avatarUrl,
    super.points,
    super.totalRides,
    super.referralCode,
    super.preferredLanguage,
    super.isActive,
    super.createdAt,
    super.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'passenger',
      avatarUrl: json['avatar_url'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
      totalRides: (json['total_rides'] as num?)?.toInt() ?? 0,
      referralCode: json['referral_code'] as String?,
      preferredLanguage: json['preferred_language'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'points': points,
      'total_rides': totalRides,
      'referral_code': referralCode,
      'preferred_language': preferredLanguage,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (preferredLanguage != null) data['preferred_language'] = preferredLanguage;
    return data;
  }

  static UserModel fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      phone: entity.phone,
      fullName: entity.fullName,
      role: entity.role,
      avatarUrl: entity.avatarUrl,
      points: entity.points,
      totalRides: entity.totalRides,
      referralCode: entity.referralCode,
      preferredLanguage: entity.preferredLanguage,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
