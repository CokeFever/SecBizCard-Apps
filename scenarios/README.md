
# Handshake Simulation Test

Overview:
This test located at `test/scenarios/handshake_simulation_test.dart` simulates the "Two User" workflow using strict mocks for Repositories. It allows you to verify the Handshake logic, URL generation, and Deep Link routing without manually releasing the app or using two physical devices.

## How to Run
Run the following command in your terminal:

```bash
flutter test test/scenarios/handshake_simulation_test.dart
```

## Scenarios Covered
1.  **User A (Alice)**: Signs in and generates a Handshake Link.
    - Uses `FakeHandshakeRepository` to "create" a session.
    - Generates a URL like `/handshake/session_business_123`.
2.  **Switch User**: The test programmatically signs out Alice and signs in User B (Bob).
3.  **User B (Bob)**: Simulates "Scanning" the QR code by navigating to the generated URL.
4.  **Verification**: Checks that Bob lands on the correct screen and sees Alice's data.

## Modifying the Test
- **Repositories**: You can adjust `FakeHandshakeRepository` to return different error states (e.g. `deadline-exceeded` for expired sessions) to test your error UI.
- **Profiles**: You can modify `fakeProfile` to test different user attributes.
