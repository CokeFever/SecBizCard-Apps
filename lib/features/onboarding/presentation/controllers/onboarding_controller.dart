import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

part 'onboarding_controller.g.dart';

class OnboardingState {
  final int currentStep;
  final UserProfile? draftProfile;
  final bool isLoading;
  final String? error;

  OnboardingState({
    this.currentStep = 0,
    this.draftProfile,
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    int? currentStep,
    UserProfile? draftProfile,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      draftProfile: draftProfile ?? this.draftProfile,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Allow nulling out error
    );
  }
}

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingState build() {
    return OnboardingState();
  }

  void init(UserProfile? initialProfile) {
    if (state.draftProfile == null && initialProfile != null) {
      state = state.copyWith(draftProfile: initialProfile);
    }
  }

  Future<void> importFromGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    final currentUser = ref.read(authRepositoryProvider).getCurrentUser();
    if (currentUser == null) {
      state = state.copyWith(isLoading: false, error: 'User not signed in');
      return;
    }

    final contactsRepo = ref.read(contactsRepositoryProvider);
    final result = await contactsRepo.fetchSelfProfile(currentUser.uid);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (profile) {
        // Merge with existing draft if any, but prioritize imported data
        state = state.copyWith(
          draftProfile: profile,
          isLoading: false,
          currentStep: 1, // Move to next step (Review)
        );
      },
    );
  }

  void skipImport() {
    state = state.copyWith(currentStep: 1);
  }

  void updateDraft(UserProfile profile) {
    state = state.copyWith(draftProfile: profile);
  }

  void nextStep() {
    if (state.currentStep < 3) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> completeOnboarding() async {
    if (state.draftProfile == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    final finalProfile = state.draftProfile!.copyWith(
      isOnboardingComplete: true,
    );

    final profileRepo = ref.read(profileRepositoryProvider);
    final result = await profileRepo.createOrUpdateUser(finalProfile);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }
}
