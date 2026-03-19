import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fpdart/fpdart.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/presentation/controllers/edit_profile_controller.dart';

import 'test_mocks.mocks.dart';
import 'test_helper.dart';

void main() {
  late MockProfileRepository mockProfileRepo;
  late ProviderContainer container;

  setUp(() {
    setupTestDummies();
    mockProfileRepo = MockProfileRepository();
    container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(mockProfileRepo)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('EditProfileController', () {
    final tUser = UserProfile(
      uid: 'test_uid',
      email: 'test@example.com',
      displayName: 'Test User',
      createdAt: DateTime.now(),
    );

    test('saveProfile success updates state to AsyncData(null)', () async {
      // Arrange
      when(
        mockProfileRepo.createOrUpdateUser(tUser),
      ).thenAnswer((_) async => const Right(unit));

      final controller = container.read(editProfileControllerProvider.notifier);

      // Act
      await controller.saveProfile(tUser);

      // Assert
      final state = container.read(editProfileControllerProvider);
      expect(state, const AsyncData<void>(null));
      verify(mockProfileRepo.createOrUpdateUser(tUser)).called(1);
    });

    test('saveProfile failure updates state to AsyncError', () async {
      // Arrange
      const failure = GeneralFailure('Save failed');
      when(
        mockProfileRepo.createOrUpdateUser(tUser),
      ).thenAnswer((_) async => const Left(failure));

      final controller = container.read(editProfileControllerProvider.notifier);

      // Act
      await controller.saveProfile(tUser);

      // Assert
      final state = container.read(editProfileControllerProvider);
      expect(state, isA<AsyncError>());
      expect(state.error, 'Save failed');
      verify(mockProfileRepo.createOrUpdateUser(tUser)).called(1);
    });
  });
}
