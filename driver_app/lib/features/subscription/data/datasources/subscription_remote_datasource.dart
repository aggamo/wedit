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
          .select()
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
      final endsAt = _calculateEndsAt(plan, now);
      final amount = _getPlanPrice(plan);

      // For bank transfer, create pending subscription
      final status = paymentMethod == 'bank_transfer' ? 'pending' : 'active';

      final data = await _supabase
          .from(AppConstants.subscriptionsTable)
          .insert({
            'driver_id': driverId,
            'plan': plan,
            'amount': amount,
            'status': status,
            'starts_at': now.toIso8601String(),
            'ends_at': endsAt.toIso8601String(),
            'payment_method': paymentMethod,
            'auto_renew': false,
          })
          .select()
          .single();

      // Update driver subscription status if active
      if (status == 'active') {
        await _supabase
            .from(AppConstants.driversTable)
            .update({'has_active_subscription': true})
            .eq('id', driverId);
      }

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

      // Record in payment_receipts table
      await _supabase.from('payment_receipts').insert({
        'driver_id': driverId,
        'amount': amount,
        'receipt_url': url,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });
    } on StorageException catch (e) {
      throw UploadFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  DateTime _calculateEndsAt(String plan, DateTime from) {
    switch (plan) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return from.add(const Duration(days: 30));
      default:
        return from.add(const Duration(days: 1));
    }
  }

  double _getPlanPrice(String plan) {
    switch (plan) {
      case 'daily':
        return AppConstants.dailyPrice;
      case 'weekly':
        return AppConstants.weeklyPrice;
      case 'monthly':
        return AppConstants.monthlyPrice;
      default:
        return AppConstants.dailyPrice;
    }
  }

  SubscriptionEntity _mapToEntity(Map<String, dynamic> data) {
    return SubscriptionEntity(
      id: data['id'] as String,
      driverId: data['driver_id'] as String,
      plan: data['plan'] as String,
      amount: (data['amount'] as num).toDouble(),
      status: data['status'] as String,
      startsAt: DateTime.parse(data['starts_at'] as String),
      endsAt: DateTime.parse(data['ends_at'] as String),
      autoRenew: data['auto_renew'] as bool? ?? false,
      paymentMethod: data['payment_method'] as String?,
      receiptUrl: data['receipt_url'] as String?,
    );
  }
}
