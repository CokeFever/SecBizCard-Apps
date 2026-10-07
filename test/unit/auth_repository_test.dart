import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/mockito.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/settings/data/magic_word_service.dart';
import 'package:secbizcard/features/settings/data/ocr_settings_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;

import 'package:fpdart/fpdart.dart';
import 'package:secbizcard/core/errors/failure.dart';

import 'test_mocks.mocks.dart';
import 'package:riverpod/riverpod.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'test_helper.dart';

/// A minimal fake [Ref] for AuthRepository. The repository's `_init()` only
/// uses `ref.read(authInitializationStateProvider.notifier).state = false`, so
/// we return a real StateController for that provider and throw for anything
/// unexpected. Using a hand-written fake (instead of a mockito mock) avoids the
/// "Cannot call when within a stub response" problem caused by evaluating the
/// provider argument through a mock during stubbing.
class FakeRef extends Fake implements Ref {
  final StateController<bool> initController = StateController<bool>(true);

  @override
  T read<T>(ProviderListenable<T> provider) {
    // AuthRepository._init only reads authInitializationStateProvider.notifier,
    // so returning the shared StateController for any read is sufficient here.
    return initController as T;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Capture flutter_secure_storage calls so we can assert sign-out clears both
  // the BYOK key and the magic word (both constructed directly in signOut).
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final deletedKeys = <String>[];

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
      if (call.method == 'delete') {
        final key = (call.arguments as Map)['key'] as String?;
        if (key != null) deletedKeys.add(key);
      }
      // Return null for read/write/delete; shape is fine for these calls.
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  late AuthRepository authRepo;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignIn mockContactsGoogleSignIn;
  late MockProfileRepository mockProfileRepo;
  late FakeRef fakeRef;

  setUp(() {
    setupTestDummies();
    deletedKeys.clear();
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockContactsGoogleSignIn = MockGoogleSignIn();
    mockProfileRepo = MockProfileRepository();
    fakeRef = FakeRef();
    // Ensure _init()'s stream path terminates deterministically: no cached
    // user, empty auth stream (NiceMock returns an empty stream by default,
    // but be explicit so the timeout path isn't hit).
    when(mockFirebaseAuth.currentUser).thenReturn(null);
    when(mockFirebaseAuth.authStateChanges())
        .thenAnswer((_) => const Stream<fire_auth.User?>.empty());
    authRepo = AuthRepository(
      mockFirebaseAuth,
      mockGoogleSignIn,
      fakeRef,
      contactsGoogleSignIn: mockContactsGoogleSignIn,
    );
  });

  group('AuthRepository', () {
    test('getCurrentUser returns firebase user', () {
      final mockUser = MockUser();
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

      final result = authRepo.getCurrentUser();

      expect(result, mockUser);
    });

    test('signInWithGoogle success - new user', () async {
      final mockGoogleAccount = MockGoogleSignInAccount();
      final mockGoogleAuth = MockGoogleSignInAuthentication();
      final mockUserCredential = MockUserCredential();
      final mockUser = MockUser();

      when(
        mockGoogleSignIn.signIn(),
      ).thenAnswer((_) async => mockGoogleAccount);
      when(
        mockGoogleAccount.authentication,
      ).thenAnswer((_) async => mockGoogleAuth);
      when(mockGoogleAuth.accessToken).thenReturn('access_token');
      when(mockGoogleAuth.idToken).thenReturn('id_token');

      when(
        mockFirebaseAuth.signInWithCredential(any),
      ).thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_uid');
      when(mockUser.email).thenReturn('test@example.com');
      when(mockUser.displayName).thenReturn('Test User');
      when(mockUser.photoURL).thenReturn('photo_url');

      // User doesn't exist in firestore
      when(
        mockProfileRepo.getUser(argThat(isA<String>())),
      ).thenAnswer((_) async => const Left(GeneralFailure('Not found')));
      when(
        mockProfileRepo.createOrUpdateUser(argThat(isA<UserProfile>())),
      ).thenAnswer((_) async => const Right(unit));

      final result = await authRepo.signInWithGoogle(mockProfileRepo);

      expect(result.isRight(), true);
      verify(mockProfileRepo.createOrUpdateUser(argThat(isA<UserProfile>()))).called(1);
    });

    test('signInWithGoogle failure - user canceled', () async {
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final result = await authRepo.signInWithGoogle(mockProfileRepo);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, 'Google Sign-In canceled'),
        (_) => fail('Should have failed'),
      );
    });
    test('signOut calls sign out on providers', () async {
      final mockUser = MockUser();
      final mockIdTokenResult = MockIdTokenResult();
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(mockUser.getIdTokenResult()).thenAnswer(
        (_) async => mockIdTokenResult,
      );
      when(mockIdTokenResult.signInProvider).thenReturn('google.com');
      when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});
      when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
      when(mockContactsGoogleSignIn.signOut()).thenAnswer((_) async => null);

      await authRepo.signOut();

      verify(mockFirebaseAuth.signOut()).called(1);
      // Logout must clear BOTH independent Google instances (drive.file and
      // contacts) so no Google grant lingers for the next account.
      verify(mockGoogleSignIn.signOut()).called(1);
      verify(mockContactsGoogleSignIn.signOut()).called(1);
      // Sign-out must also clear the BYOK key AND the magic word from secure
      // storage (each fault-isolated), so a shared device leaves no trace.
      expect(deletedKeys, contains(OcrSettingsService.kApiKeyForTest));
      expect(deletedKeys, contains(MagicWordService.kMagicWord));
    });
  });

  group('Google Sign-In instance split', () {
    test('Drive and Contacts receive DISTINCT GoogleSignIn instances', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final driveInstance = container.read(driveGoogleSignInProvider);
      final contactsInstance = container.read(contactsGoogleSignInProvider);

      // The whole point of the fix: the two features must never share one
      // GoogleSignIn object, else requesting the pending-verification contacts
      // scope poisons the shared grant and breaks the drive.file token request.
      expect(identical(driveInstance, contactsInstance), isFalse);

      // Both keep the Firebase web client ID so the Google credential still
      // links to the correct web client.
      expect(driveInstance.serverClientId, contactsInstance.serverClientId);
      expect(
        driveInstance.serverClientId,
        '769422548283-rvuciu2cmfj9149fudj9q59pql4ofo8q.apps.googleusercontent.com',
      );
    });
  });
}
