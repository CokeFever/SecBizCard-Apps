import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/mockito.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'test_mocks.mocks.dart';
import 'test_helper.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockContactsRepository mockContactsRepo;
  late MockProfileRepository mockProfileRepo;
  late ProviderContainer container;

  setUp(() {
    setupTestDummies();
    mockAuthRepo = MockAuthRepository();
    mockContactsRepo = MockContactsRepository();
    mockProfileRepo = MockProfileRepository();

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        contactsRepositoryProvider.overrideWithValue(mockContactsRepo),
        profileRepositoryProvider.overrideWithValue(mockProfileRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('OnboardingController', () {
    test('initial state is correct', () {
      expect(container.read(onboardingControllerProvider).currentStep, 0);
      expect(container.read(onboardingControllerProvider).isLoading, false);
    });

    test('importFromGoogle success', () async {
      final mockUser = MockUser();
      final testProfile = UserProfile(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      when(mockAuthRepo.getCurrentUser()).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_uid');
      when(
        mockContactsRepo.fetchSelfProfile('test_uid'),
      ).thenAnswer((_) async => Right(testProfile));

      final controller = container.read(onboardingControllerProvider.notifier);
      await controller.importFromGoogle();

      final state = container.read(onboardingControllerProvider);
      expect(state.currentStep, 1);
      expect(state.draftProfile, testProfile);
      expect(state.isLoading, false);
    });

    test('completeOnboarding success', () async {
      final testProfile = UserProfile(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.now(),
      );

      final controller = container.read(onboardingControllerProvider.notifier);
      controller.updateDraft(testProfile);

      when(
        mockProfileRepo.createOrUpdateUser(any),
      ).thenAnswer((_) async => const Right(unit));

      final result = await controller.completeOnboarding();

      expect(result, true);
      verify(mockProfileRepo.createOrUpdateUser(any)).called(1);
    });
  });
}
