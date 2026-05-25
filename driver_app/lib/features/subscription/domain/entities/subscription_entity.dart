class SubscriptionEntity {
  final String id;
  final String driverId;
  final String plan; // daily, weekly, monthly
  final double amount;
  final String status; // pending, active, expired, cancelled
  final DateTime startsAt;
  final DateTime endsAt;
  final bool autoRenew;
  final DateTime? renewalNotifiedAt;
  final String? paymentMethod;
  final String? receiptUrl;

  const SubscriptionEntity({
    required this.id,
    required this.driverId,
    required this.plan,
    required this.amount,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.autoRenew = false,
    this.renewalNotifiedAt,
    this.paymentMethod,
    this.receiptUrl,
  });

  bool get isActive => status == 'active' && endsAt.isAfter(DateTime.now());
  bool get isExpired => status == 'expired' || endsAt.isBefore(DateTime.now());
  bool get isPending => status == 'pending';

  Duration get remaining => endsAt.difference(DateTime.now());
  int get remainingDays => remaining.inDays;
  int get remainingHours => remaining.inHours % 24;

  String get planLabel {
    switch (plan) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return plan;
    }
  }

  SubscriptionEntity copyWith({
    String? id,
    String? driverId,
    String? plan,
    double? amount,
    String? status,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? autoRenew,
    DateTime? renewalNotifiedAt,
    String? paymentMethod,
    String? receiptUrl,
  }) {
    return SubscriptionEntity(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      plan: plan ?? this.plan,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      autoRenew: autoRenew ?? this.autoRenew,
      renewalNotifiedAt: renewalNotifiedAt ?? this.renewalNotifiedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }
}
