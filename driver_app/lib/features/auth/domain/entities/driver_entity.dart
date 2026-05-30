class DriverEntity {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final String status; // pending, approved, rejected, suspended
  final double rating;
  final int totalRides;
  final String? referralCode;
  final String? referredBy;
  final DateTime createdAt;
  final bool hasActiveSubscription;
  final String? fcmToken;
  final String role; // 'driver' or 'fleet_owner'
  final bool isFleetOwner;

  const DriverEntity({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.avatarUrl,
    this.status = 'pending',
    this.rating = 5.0,
    this.totalRides = 0,
    this.referralCode,
    this.referredBy,
    required this.createdAt,
    this.hasActiveSubscription = false,
    this.fcmToken,
    this.role = 'driver',
    this.isFleetOwner = false,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';
  bool get isRegistrationComplete => name != null && name!.isNotEmpty;

  DriverEntity copyWith({
    String? id,
    String? phone,
    String? name,
    String? email,
    String? avatarUrl,
    String? status,
    double? rating,
    int? totalRides,
    String? referralCode,
    String? referredBy,
    DateTime? createdAt,
    bool? hasActiveSubscription,
    String? fcmToken,
    String? role,
    bool? isFleetOwner,
  }) {
    return DriverEntity(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      totalRides: totalRides ?? this.totalRides,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      createdAt: createdAt ?? this.createdAt,
      hasActiveSubscription: hasActiveSubscription ?? this.hasActiveSubscription,
      fcmToken: fcmToken ?? this.fcmToken,
      role: role ?? this.role,
      isFleetOwner: isFleetOwner ?? this.isFleetOwner,
    );
  }
}
