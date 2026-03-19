import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mockito/annotations.dart';
import 'package:secbizcard/features/profile/data/datasources/profile_local_datasource.dart';
import 'package:firebase_auth/firebase_auth.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<FirebaseFunctions>(),
  MockSpec<ProfileLocalDataSource>(),
  MockSpec<CollectionReference>(),
  MockSpec<DocumentReference>(),
  MockSpec<DocumentSnapshot>(),
  MockSpec<UserCredential>(),
  MockSpec<User>(),
])
void main() {}
