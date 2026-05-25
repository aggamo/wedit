import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_datasource.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDatasource _datasource;

  SubscriptionRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, SubscriptionEntity?>> getActiveSubscription() async {
    try {
      final sub = await _datasource.getActiveSubscription();
      return Right(sub);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SubscriptionEntity>> createSubscription(
      String plan, String paymentMethod) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return const Left(AuthFailure('Not authenticated'));

      final sub = await _datasource.createSubscription(userId, plan, paymentMethod);
      return Right(sub);
    } on ServerFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleAutoRenew(
      String subscriptionId, bool enabled) async {
    try {
      await _datasource.toggleAutoRenew(subscriptionId, enabled);
      return const Right(null);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> uploadBankTransferReceipt(
      File file, double amount) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return const Left(AuthFailure('Not authenticated'));

      await _datasource.uploadBankTransferReceipt(userId, file, amount);
      return const Right(null);
    } on UploadFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
