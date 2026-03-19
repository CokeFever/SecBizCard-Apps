import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/mockito.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';

import 'package:fpdart/fpdart.dart';
import 'package:secbizcard/core/errors/failure.dart';

import 'test_mocks.mocks.dart';
import 'test_helper.dart';

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockProfileRepository mockProfileRepo;
  late AuthRepository authRepo;

  setUp(() {
    setupTestDummies();
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockProfileRepo = MockProfileRepository();

    authRepo = AuthRepository(mockFirebaseAuth, mockGoogleSignIn);
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
        mockProfileRepo.getUser(any),
      ).thenAnswer((_) async => const Left(GeneralFailure('Not found')));
      when(
        mockProfileRepo.createOrUpdateUser(any),
      ).thenAnswer((_) async => const Right(unit));

      final result = await authRepo.signInWithGoogle(mockProfileRepo);

      expect(result.isRight(), true);
      verify(mockProfileRepo.createOrUpdateUser(any)).called(1);
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

      await authRepo.signOut();

      verify(mockFirebaseAuth.signOut()).called(1);
      verify(mockGoogleSignIn.signOut()).called(1);
    });
  });
}
