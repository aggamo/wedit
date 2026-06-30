class SubscriptionEntity {
  final String id;
  final String driverId;
  final String plan;
  final double amount;
  final String status; // pending, active, expired, cancelled
  final DateTime startsAt;
  final DateTime? endsAt;       // null for active_days/no_expiry plans
  final bool autoRenew;
  final DateTime? renewalNotifiedAt;
  final String? paymentMethod;
  final String? receiptUrl;

  // Gamification fields (added in migration 017/018)
  final String? subscriptionPlanId;
  final bool isFrozen;
  final bool isTrial;
  final bool useActiveDays;
  final bool noExpiry;
  final int activeDaysUsed;
  final int? activeDaysQuota;

  const SubscriptionEntity({
    required this.id,
    required this.driverId,
    required this.plan,
    required this.amount,
    required this.status,
    required this.startsAt,
    this.endsAt,
    this.autoRenew = false,
    this.renewalNotifiedAt,
    this.paymentMethod,
    this.receiptUrl,
    this.subscriptionPlanId,
    this.isFrozen = false,
    this.isTrial = false,
    this.useActiveDays = false,
    this.noExpiry = false,
    this.activeDaysUsed = 0,
    this.activeDaysQuota,
  });

  bool get isActive {
    if (status != 'active') return false;
    if (isFrozen) return false;
    if (useActiveDays) return true; // active_days plans expire via active_days_used
    if (noExpiry) return true;
    return endsAt == null || endsAt!.isAfter(DateTime.now());
  }

  bool get isExpired {
    if (status == 'expired') return true;
    if (useActiveDays && activeDaysQuota != null) {
      return activeDaysUsed >= activeDaysQuota!;
    }
    if (endsAt != null && !noExpiry) return endsAt!.isBefore(DateTime.now());
    return false;
  }

  bool get isPending => status == 'pending';

  /// Remaining calendar days (null for active_days plans)
  int? get remainingCalendarDays {
    if (endsAt == null) return null;
    final diff = endsAt!.difference(DateTime.now());
    return diff.inDays.clamp(0, 99999);
  }

  /// Remaining active days quota
  int? get remainingActiveDays {
    if (!useActiveDays || activeDaysQuota == null) return null;
    return (activeDaysQuota! - activeDaysUsed).clamp(0, activeDaysQuota!);
  }

  String get planLabel {
    switch (plan) {
      case 'trial':  return 'تجربة مجانية';
      case 'daily':  return 'يومي';
      case 'weekly': return 'أسبوعي';
      case 'flex':   return 'فليكس باس';
      case 'basic':  return 'أساسي';
      case 'pro':    return 'احترافي';
      case 'fleet':  return 'أسطول';
      default:       return plan;
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
    String? subscriptionPlanId,
    bool? isFrozen,
    bool? isTrial,
    bool? useActiveDays,
    bool? noExpiry,
    int? activeDaysUsed,
    int? activeDaysQuota,
  }) {
    return SubscriptionEntity(
      id:                 id                 ?? this.id,
      driverId:           driverId           ?? this.driverId,
      plan:               plan               ?? this.plan,
      amount:             amount             ?? this.amount,
      status:             status             ?? this.status,
      startsAt:           startsAt           ?? this.startsAt,
      endsAt:             endsAt             ?? this.endsAt,
      autoRenew:          autoRenew          ?? this.autoRenew,
      renewalNotifiedAt:  renewalNotifiedAt  ?? this.renewalNotifiedAt,
      paymentMethod:      paymentMethod      ?? this.paymentMethod,
      receiptUrl:         receiptUrl         ?? this.receiptUrl,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      isFrozen:           isFrozen           ?? this.isFrozen,
      isTrial:            isTrial            ?? this.isTrial,
      useActiveDays:      useActiveDays      ?? this.useActiveDays,
      noExpiry:           noExpiry           ?? this.noExpiry,
      activeDaysUsed:     activeDaysUsed     ?? this.activeDaysUsed,
      activeDaysQuota:    activeDaysQuota    ?? this.activeDaysQuota,
    );
  }
}
