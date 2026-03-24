import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:google_sign_in/google_sign_in.dart' as google_sign_in;
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:secbizcard/features/profile/data/datasources/profile_local_datasource.dart';

@GenerateNiceMocks([
  MockSpec<fire_auth.FirebaseAuth>(),
  MockSpec<fire_auth.User>(),
  MockSpec<fire_auth.UserCredential>(),
  MockSpec<fire_auth.IdTokenResult>(),
  MockSpec<google_sign_in.GoogleSignIn>(),
  MockSpec<google_sign_in.GoogleSignInAccount>(),
  MockSpec<google_sign_in.GoogleSignInAuthentication>(),
  MockSpec<ProfileRepository>(),
  MockSpec<ContactsRepository>(),
  MockSpec<AuthRepository>(),
  MockSpec<DriveRepository>(),
  MockSpec<FirebaseFirestore>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<ProfileLocalDataSource>(),
  MockSpec<CollectionReference>(),
  MockSpec<DocumentReference>(),
  MockSpec<DocumentSnapshot>(),
])
void main() {}
