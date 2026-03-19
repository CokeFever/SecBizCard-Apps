import 'package:mockito/mockito.dart';
import 'package:fpdart/fpdart.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

void setupTestDummies() {
  provideDummy<Either<Failure, UserProfile>>(
    const Left(GeneralFailure('dummy')),
  );
  provideDummy<Either<Failure, Unit>>(const Right(unit));
}
