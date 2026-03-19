import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

part 'edit_profile_controller.g.dart';

@riverpod
class EditProfileController extends _$EditProfileController {
  @override
  FutureOr<void> build() {
    // Initial state is void (idle)
    return null;
  }

  Future<void> saveProfile(UserProfile user) async {
    state = const AsyncLoading();
    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.createOrUpdateUser(user);

    result.fold(
      (failure) => state = AsyncError(failure.message, StackTrace.current),
      (success) => state = const AsyncData(null),
    );
  }
}
