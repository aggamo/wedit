import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/subscription_entity.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, SubscriptionEntity?>> getActiveSubscription();
  Future<Either<Failure, SubscriptionEntity>> createSubscription(
      String plan, String paymentMethod);
  Future<Either<Failure, void>> toggleAutoRenew(
      String subscriptionId, bool enabled);
  Future<Either<Failure, void>> uploadBankTransferReceipt(
      File file, double amount);
}
