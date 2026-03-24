import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/people/v1.dart' as people;
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/contacts/data/datasources/contacts_local_datasource.dart';
import 'package:secbizcard/features/profile/data/datasources/profile_local_datasource.dart';

part 'contacts_repository.g.dart';

@riverpod
Future<List<UserProfile>> savedContacts(Ref ref) async {
  final currentUserId = ref.watch(authStateProvider).value?.uid;
  final repository = ref.watch(contactsRepositoryProvider);
  
  final result = await repository.getSavedContacts();
  return result.fold(
    (l) => [], 
    (r) => currentUserId != null 
        ? r.where((profile) => profile.uid != currentUserId).toList()
        : r,
  );
}

@riverpod
ContactsRepository contactsRepository(Ref ref) {
  return ContactsRepository(
    ref.watch(googleSignInProvider),
    ref.watch(profileLocalDataSourceProvider),
    ref.watch(contactsLocalDataSourceProvider),
  );
}

class ContactsRepository {
  final GoogleSignIn _googleSignIn;
  final ProfileLocalDataSource _profileLocalDataSource;
  final ContactsLocalDataSource _contactsLocalDataSource;

  ContactsRepository(
    this._googleSignIn,
    this._profileLocalDataSource,
    this._contactsLocalDataSource,
  );

  /// Saves a contact to local database
  Future<Either<Failure, void>> saveContactLocally(UserProfile profile) async {
    try {
      // 1. Save the profile data (using existing profile cache mechanism)
      await _profileLocalDataSource.saveUser(profile);

      // 2. Mark as saved contact
      await _contactsLocalDataSource.saveContact(profile.uid);

      return right(null);
    } catch (e) {
      return left(GeneralFailure('Failed to save contact locally: $e'));
    }
  }

  /// Deletes a contact locally
  Future<Either<Failure, void>> deleteContact(String contactUid) async {
    try {
      await _contactsLocalDataSource.deleteContact(contactUid);
      return right(null);
    } catch (e) {
      return left(GeneralFailure('Failed to delete contact: $e'));
    }
  }

  /// Saves a user profile to Google Contacts
  Future<Either<Failure, void>> saveToGoogleContacts(
    UserProfile profile, {
    bool forceAccountSelection = false,
  }) async {
    try {
      // Get authenticated HTTP client
      if (forceAccountSelection) {
        await _googleSignIn.signOut();
      }

      final account = await _googleSignIn.signIn();
      if (account == null) {
        return left(const AuthFailure('User not signed in'));
      }

      final authHeaders = await account.authHeaders;
      final authenticatedClient = _GoogleAuthClient(authHeaders);

      // Create People API client
      final peopleApi = people.PeopleServiceApi(authenticatedClient);

      // Create contact
      final person = people.Person(
        names: [people.Name(givenName: profile.displayName)],
        emailAddresses: [people.EmailAddress(value: profile.email)],
        phoneNumbers: profile.phone != null
            ? [people.PhoneNumber(value: profile.phone)]
            : null,
        organizations: profile.company != null
            ? [people.Organization(name: profile.company, title: profile.title)]
            : null,
      );

      // Save to Google Contacts
      await peopleApi.people.createContact(person);

      return right(null);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Fetches the user's own profile from Google People API
  Future<Either<Failure, UserProfile>> fetchSelfProfile(String uid) async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return left(const AuthFailure('User not signed in'));
      }

      final authHeaders = await account.authHeaders;
      final authenticatedClient = _GoogleAuthClient(authHeaders);
      final peopleApi = people.PeopleServiceApi(authenticatedClient);

      // Get 'people/me'
      final person = await peopleApi.people.get(
        'people/me',
        personFields:
            'names,emailAddresses,phoneNumbers,organizations,addresses,photos',
      );

      // Map to UserProfile
      final name =
          person.names?.firstOrNull?.displayName ?? account.displayName ?? '';
      final email = person.emailAddresses?.firstOrNull?.value ?? account.email;
      final phone = person.phoneNumbers?.firstOrNull?.value;
      final photoUrl = person.photos?.firstOrNull?.url ?? account.photoUrl;

      String? company;
      String? title;
      if (person.organizations != null && person.organizations!.isNotEmpty) {
        company = person.organizations!.first.name;
        title = person.organizations!.first.title;
      }

      final profile = UserProfile(
        uid: uid,
        email: email,
        displayName: name,
        photoUrl: photoUrl,
        phone: phone,
        company: company,
        title: title,
        createdAt: DateTime.now(),
        isOnboardingComplete: false,
      );

      return right(profile);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Retrieves all locally saved contacts
  Future<Either<Failure, List<UserProfile>>> getSavedContacts() async {
    try {
      // 1. Get List of UIDs
      final uids = await _contactsLocalDataSource.getSavedContacts();

      if (uids.isEmpty) return right([]);

      // 2. Fetch profiles for each UID
      // Note: This could be optimized with a batch query if the Datasource supported it.
      final List<UserProfile> profiles = [];
      for (final uid in uids) {
        final profile = await _profileLocalDataSource.getUser(uid);
        if (profile != null) {
          profiles.add(profile);
        }
      }

      return right(profiles);
    } catch (e) {
      return left(GeneralFailure('Failed to load contacts: $e'));
    }
  }
}

/// HTTP client that adds authentication headers
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
