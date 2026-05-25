import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/driver_registration_entity.dart';
import '../../domain/repositories/registration_repository.dart';
import '../datasources/registration_remote_datasource.dart';

class RegistrationRepositoryImpl implements RegistrationRepository {
  final RegistrationRemoteDatasource _datasource;

  RegistrationRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, void>> submitRegistration(
      DriverRegistrationEntity entity) async {
    try {
      await _datasource.submitRegistration(entity);
      return const Right(null);
    } on ServerFailure catch (e) {
      return Left(e);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDocument(File file, String type) async {
    try {
      final url = await _datasource.uploadDocument(file, type);
      return Right(url);
    } on UploadFailure catch (e) {
      return Left(e);
    } on AuthFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getRegistrationStatus() async {
    try {
      final status = await _datasource.getRegistrationStatus();
      return Right(status);
    } on ServerFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
