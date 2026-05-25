import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String phone;
  final String? fullName;
  final String role;
  final String? avatarUrl;
  final int points;
  final int totalRides;
  final String? referralCode;
  final String? preferredLanguage;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserEntity({
    required this.id,
    required this.phone,
    this.fullName,
    this.role = 'passenger',
    this.avatarUrl,
    this.points = 0,
    this.totalRides = 0,
    this.referralCode,
    this.preferredLanguage,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  bool get isProfileComplete =>
      fullName != null && fullName!.isNotEmpty;

  String get loyaltyTier {
    if (totalRides >= 100) return 'gold';
    if (totalRides >= 30) return 'silver';
    return 'bronze';
  }

  String get displayName => fullName ?? phone;

  String get initials {
    if (fullName == null || fullName!.isEmpty) return phone.substring(0, 2);
    final parts = fullName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName![0].toUpperCase();
  }

  UserEntity copyWith({
    String? id,
    String? phone,
    String? fullName,
    String? role,
    String? avatarUrl,
    int? points,
    int? totalRides,
    String? referralCode,
    String? preferredLanguage,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      points: points ?? this.points,
      totalRides: totalRides ?? this.totalRides,
      referralCode: referralCode ?? this.referralCode,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        phone,
        fullName,
        role,
        avatarUrl,
        points,
        totalRides,
        referralCode,
        preferredLanguage,
        isActive,
      ];
}
