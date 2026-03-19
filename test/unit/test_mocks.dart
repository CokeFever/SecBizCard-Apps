import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';

@GenerateMocks([
  fire_auth.FirebaseAuth,
  fire_auth.User,
  fire_auth.UserCredential,
  fire_auth.IdTokenResult,
  google_sign_in.GoogleSignIn,
  google_sign_in.GoogleSignInAccount,
  google_sign_in.GoogleSignInAuthentication,
  ProfileRepository,
  ContactsRepository,
  AuthRepository,
  DriveRepository,
])
void main() {}
