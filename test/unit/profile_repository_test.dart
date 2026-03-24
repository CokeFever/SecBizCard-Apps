import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fpdart/fpdart.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/core/errors/failure.dart';

import 'test_mocks.mocks.dart';

void main() {
  late ProfileRepository repository;
  late MockProfileLocalDataSource mockLocalDataSource;

  setUp(() {
    mockLocalDataSource = MockProfileLocalDataSource();

    repository = ProfileRepository(mockLocalDataSource);
  });

  const tUid = 'test-uid';
  final tUser = UserProfile(
    uid: tUid,
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: DateTime.now(),
  );

  group('getUser', () {
    test('should return user from Local DataSource if available', () async {
      // Arrange
      when(mockLocalDataSource.getUser(tUid)).thenAnswer((_) async => tUser);

      // Act
      final result = await repository.getUser(tUid);

      // Assert
      expect(result, Right(tUser));
      verify(mockLocalDataSource.getUser(tUid));
    });

    test('should return Failure when user is not found locally', () async {
      // Arrange
      when(mockLocalDataSource.getUser(tUid)).thenAnswer((_) async => null);

      // Act
      final result = await repository.getUser(tUid);

      // Assert
      expect(result.isLeft(), true);
      verify(mockLocalDataSource.getUser(tUid));
    });
  });

  group('createOrUpdateUser', () {
    test(
      'should save user with business domain when email is business',
      () async {
        // Arrange
        final businessUser = tUser.copyWith(email: 'john@corp.com');
        final expectedUser = businessUser.copyWith(
          businessEmailDomain: 'corp.com',
        );
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async {});

        // Act
        final result = await repository.createOrUpdateUser(businessUser);

        // Assert
        expect(result, const Right(unit));
        verify(mockLocalDataSource.saveUser(expectedUser));
      },
    );

    test(
      'should save user without business domain when email is public',
      () async {
        // Arrange
        final publicUser = tUser.copyWith(email: 'john@gmail.com');
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async {});

        // Act
        final result = await repository.createOrUpdateUser(publicUser);

        // Assert
        expect(result, const Right(unit));
        verify(mockLocalDataSource.saveUser(publicUser));
      },
    );
  });

  group('markEmailAsVerified', () {
    test(
      'should update emailVerified and save user when user exists',
      () async {
        // Arrange
        when(mockLocalDataSource.getUser(tUid)).thenAnswer((_) async => tUser);
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async {});

        // Act
        final result = await repository.markEmailAsVerified(tUid);

        // Assert
        expect(result, const Right(unit));
        verify(mockLocalDataSource.getUser(tUid));

        final captured = verify(
          mockLocalDataSource.saveUser(captureAny),
        ).captured;
        final savedUser = captured.first as UserProfile;
        expect(savedUser.emailVerified, true);
        expect(savedUser.emailVerifiedAt, isNotNull);
      },
    );

    test('should return Failure when user does not exist', () async {
      // Arrange
      when(mockLocalDataSource.getUser(tUid)).thenAnswer((_) async => null);

      // Act
      final result = await repository.markEmailAsVerified(tUid);

      // Assert
      expect(result, const Left(GeneralFailure('User not found')));
      verify(mockLocalDataSource.getUser(tUid));
      verifyNever(mockLocalDataSource.saveUser(any));
    });
  });

  group('markPhoneAsVerified', () {
    const tPhone = '+1234567890';

    test(
      'should update phone verification and save user when user exists',
      () async {
        // Arrange
        when(mockLocalDataSource.getUser(tUid)).thenAnswer((_) async => tUser);
        when(mockLocalDataSource.saveUser(any)).thenAnswer((_) async {});

        // Act
        final result = await repository.markPhoneAsVerified(tUid, tPhone);

        // Assert
        expect(result, const Right(unit));
        verify(mockLocalDataSource.getUser(tUid));

        final captured = verify(
          mockLocalDataSource.saveUser(captureAny),
        ).captured;
        final savedUser = captured.first as UserProfile;
        expect(savedUser.phone, tPhone);
        expect(savedUser.phoneVerified, true);
        expect(savedUser.phoneVerifiedAt, isNotNull);
      },
    );

    test('should return Failure when user does not exist', () async {
      // Arrange
      when(mockLocalDataSource.getUser(tUid)).thenAnswer((_) async => null);

      // Act
      final result = await repository.markPhoneAsVerified(tUid, tPhone);

      // Assert
      expect(result, const Left(GeneralFailure('User not found')));
      verify(mockLocalDataSource.getUser(tUid));
      verifyNever(mockLocalDataSource.saveUser(any));
    });
  });
}
