import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/subscription_entity.dart';

abstract class SubscriptionRemoteDatasource {
  Future<SubscriptionEntity?> getActiveSubscription();
  Future<SubscriptionEntity> createSubscription(
      String driverId, String plan, String paymentMethod);
  Future<void> toggleAutoRenew(String subscriptionId, bool enabled);
  Future<void> uploadBankTransferReceipt(
      String driverId, File file, double amount);
}

class SubscriptionRemoteDatasourceImpl implements SubscriptionRemoteDatasource {
  final SupabaseClient _supabase;

  SubscriptionRemoteDatasourceImpl(this._supabase);

  @override
  Future<SubscriptionEntity?> getActiveSubscription() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _supabase
          .from(AppConstants.subscriptionsTable)
          .select(
            '*, subscription_plans(use_active_days, no_expiry, active_days_total)',
          )
          .eq('driver_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return _mapToEntity(data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<SubscriptionEntity> createSubscription(
      String driverId, String plan, String paymentMethod) async {
    try {
      final now = DateTime.now();

      // Fetch plan definition from subscription_plans table
      final planRow = await _supabase
          .from('subscription_plans')
          .select()
          .eq('plan_key', plan)
          .eq('is_active', true)
          .maybeSingle();

      final bool useActiveDays = planRow?['use_active_days'] as bool? ?? false;
      final bool noExpiry      = planRow?['no_expiry'] as bool? ?? false;
      final int? activeDaysTotal = planRow?['active_days_total'] as int?;
      final int? durationDays  = planRow?['duration_days'] as int?;
      final double amount      = (planRow?['price_etb'] as num?)?.toDouble()
          ?? _getLegacyPrice(plan);

      // Calculate ends_at:
      // - active_days plans: null (quota-based, no calendar expiry)
      // - no_expiry plans: null
      // - calendar plans: now + duration_days
      DateTime? endsAt;
      if (!useActiveDays && !noExpiry && durationDays != null && durationDays > 0) {
        endsAt = now.add(Duration(days: durationDays));
      }

      final status = paymentMethod == 'bank_transfer' ? 'pending' : 'active';

      final insertPayload = <String, dynamic>{
        'driver_id':      driverId,
        'plan':           plan,
        'amount':         amount,
        'status':         status,
        'started_at':     now.toIso8601String(),
        'ends_at':        endsAt?.toIso8601String(),
        'payment_method': paymentMethod,
        'auto_renew':     false,
        'is_trial':       plan == 'trial',
      };

      if (planRow != null) {
        insertPayload['subscription_plan_id'] = planRow['id'] as String;
        insertPayload['active_days_used']     = 0;
        insertPayload['active_days_quota']    = activeDaysTotal;
      }

      final data = await _supabase
          .from(AppConstants.subscriptionsTable)
          .insert(insertPayload)
          .select(
            '*, subscription_plans(use_active_days, no_expiry, active_days_total)',
          )
          .single();

      return _mapToEntity(data);
    } on PostgrestException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> toggleAutoRenew(String subscriptionId, bool enabled) async {
    try {
      await _supabase
          .from(AppConstants.subscriptionsTable)
          .update({'auto_renew': enabled})
          .eq('id', subscriptionId);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> uploadBankTransferReceipt(
      String driverId, File file, double amount) async {
    try {
      final extension = file.path.split('.').last;
      final fileName =
          '${driverId}_receipt_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = 'receipts/$fileName';

      await _supabase.storage
          .from(AppConstants.receiptsBucket)
          .upload(path, file);

      final url = _supabase.storage
          .from(AppConstants.receiptsBucket)
          .getPublicUrl(path);

      await _supabase.from('payment_receipts').insert({
        'driver_id':    driverId,
        'amount':       amount,
        'receipt_url':  url,
        'status':       'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });
    } on StorageException catch (e) {
      throw UploadFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  // Legacy price fallback for plans without a subscription_plans row
  double _getLegacyPrice(String plan) {
    switch (plan) {
      case 'daily':  return AppConstants.dailyPrice;
      case 'weekly': return AppConstants.weeklyPrice;
      default:       return AppConstants.dailyPrice;
    }
  }

  SubscriptionEntity _mapToEntity(Map<String, dynamic> data) {
    // Plan details may come as nested join (subscription_plans)
    final planDetails = data['subscription_plans'] as Map<String, dynamic>?;
    final bool useActiveDays = planDetails?['use_active_days'] as bool? ?? false;
    final bool noExpiry      = planDetails?['no_expiry'] as bool? ?? false;

    final endsAtStr = data['ends_at'] as String?;

    return SubscriptionEntity(
      id:                 data['id'] as String,
      driverId:           data['driver_id'] as String,
      plan:               data['plan'] as String,
      amount:             (data['amount'] as num).toDouble(),
      status:             data['status'] as String,
      startsAt:           DateTime.parse(data['started_at'] as String),
      endsAt:             endsAtStr != null ? DateTime.parse(endsAtStr) : null,
      autoRenew:          data['auto_renew'] as bool? ?? false,
      paymentMethod:      data['payment_method'] as String?,
      receiptUrl:         data['receipt_url'] as String?,
      subscriptionPlanId: data['subscription_plan_id'] as String?,
      isFrozen:           data['is_frozen'] as bool? ?? false,
      isTrial:            data['is_trial'] as bool? ?? false,
      useActiveDays:      useActiveDays,
      noExpiry:           noExpiry,
      activeDaysUsed:     data['active_days_used'] as int? ?? 0,
      activeDaysQuota:    data['active_days_quota'] as int?,
    );
  }
}
