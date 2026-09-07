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
import 'package:secbizcard/features/profile/data/profile_repository.dart';

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
    ref.watch(profileRepositoryProvider),
    ref.watch(contactsLocalDataSourceProvider),
  );
}

class ContactsRepository {
  final GoogleSignIn _googleSignIn;
  final ProfileRepository _profileRepository;
  final ContactsLocalDataSource _contactsLocalDataSource;

  ContactsRepository(
    this._googleSignIn,
    this._profileRepository,
    this._contactsLocalDataSource,
  );

  /// Saves a contact to local database
  Future<Either<Failure, void>> saveContactLocally(UserProfile profile) async {
    try {
      // 1. Save the profile data using ProfileRepository (handles images and sync)
      final result = await _profileRepository.createOrUpdateUser(profile);
      
      return result.fold(
        (l) => left(l),
        (r) async {
          // 2. Mark as saved contact
          await _contactsLocalDataSource.saveContact(profile.uid);
          return right(null);
        },
      );
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

      // Create contact — map every populated field, not just the name.
      final person = _buildPerson(profile);

      // Save to Google Contacts
      await peopleApi.people.createContact(person);

      return right(null);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// Maps a [UserProfile] into a People API [Person], populating every field
  /// we hold (not just the name). Phones are emitted as separate typed entries
  /// (work / mobile / fax) and secondary/multi-country data stored in
  /// customFields (altPhone / altAddress) is emitted too so nothing is lost on
  /// export.
  people.Person _buildPerson(UserProfile profile) {
    final cf = profile.customFields;

    // --- Phones (typed, multi-entry) ---
    final phoneNumbers = <people.PhoneNumber>[];
    void addPhone(String? value, String type) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) {
        phoneNumbers.add(people.PhoneNumber(value: v, type: type));
      }
    }

    addPhone(profile.phone, 'work');
    addPhone(profile.mobile, 'mobile');
    addPhone(cf['fax'], 'fax');
    // Multi-country / secondary phone captured during OCR (option A).
    addPhone(cf['altPhone'], 'other');

    // --- Emails ---
    final emailAddresses = <people.EmailAddress>[];
    if (profile.email != null && profile.email!.trim().isNotEmpty) {
      emailAddresses.add(
        people.EmailAddress(value: profile.email!.trim(), type: 'work'),
      );
    }

    // --- Addresses (typed, multi-entry) ---
    final addresses = <people.Address>[];
    void addAddress(String? formatted, String type) {
      final v = formatted?.trim();
      if (v != null && v.isNotEmpty) {
        addresses.add(people.Address(
          formattedValue: v,
          type: type,
          city: cf['city'],
          postalCode: cf['postalCode'],
        ));
      }
    }

    addAddress(profile.address, 'work');
    // Multi-country / secondary address captured during OCR (option A).
    addAddress(cf['altAddress'], 'other');

    // --- Website(s) ---
    final urls = <people.Url>[];
    if (profile.website != null && profile.website!.trim().isNotEmpty) {
      urls.add(people.Url(value: profile.website!.trim(), type: 'work'));
    }

    // --- Organization ---
    final organizations = <people.Organization>[];
    if ((profile.company != null && profile.company!.trim().isNotEmpty) ||
        (profile.title != null && profile.title!.trim().isNotEmpty) ||
        (profile.department != null && profile.department!.trim().isNotEmpty)) {
      organizations.add(people.Organization(
        name: profile.company,
        title: profile.title,
        department: profile.department,
      ));
    }

    return people.Person(
      names: [people.Name(givenName: profile.displayName)],
      emailAddresses: emailAddresses.isEmpty ? null : emailAddresses,
      phoneNumbers: phoneNumbers.isEmpty ? null : phoneNumbers,
      addresses: addresses.isEmpty ? null : addresses,
      urls: urls.isEmpty ? null : urls,
      organizations: organizations.isEmpty ? null : organizations,
    );
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
        final result = await _profileRepository.getUser(uid);
        result.fold(
          (l) => null,
          (profile) => profiles.add(profile),
        );
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
