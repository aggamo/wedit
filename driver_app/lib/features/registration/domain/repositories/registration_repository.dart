import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/driver_registration_entity.dart';

abstract class RegistrationRepository {
  Future<Either<Failure, void>> submitRegistration(DriverRegistrationEntity entity);
  Future<Either<Failure, String>> uploadDocument(File file, String type);
  Future<Either<Failure, String>> getRegistrationStatus();
}
