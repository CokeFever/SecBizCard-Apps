import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Safely casts untyped map from Cloud Functions', () {
    // Simulate untyped map from Firebase (mimicking the crash scenario)
    final Map<Object?, Object?> rawData = {
      'creatorProfile': <Object?, Object?>{
        'displayName': 'John Doe',
        'uid': '123',
        'email': 'john@example.com',
      },
    };

    // Attempt the safe cast logic used in HandshakeRepository
    final creatorProfile = (rawData['creatorProfile'] as Map<Object?, Object?>?)
        ?.cast<String, dynamic>();

    expect(creatorProfile, isNotNull);
    expect(creatorProfile!['displayName'], 'John Doe');
    expect(creatorProfile['uid'], '123');
  });

  test('Handles null or missing profile gracefully', () {
    final Map<Object?, Object?> rawData = {};

    final creatorProfile = (rawData['creatorProfile'] as Map<Object?, Object?>?)
        ?.cast<String, dynamic>();

    expect(creatorProfile, isNull);
  });
}
