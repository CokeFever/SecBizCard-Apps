/// A freshly created handshake session, as returned by the
/// `createHandshakeSession` Cloud Function.
///
/// The authoritative expiry is NOT carried here — it is read from the session
/// document's `expiresAt` field (server time) via the Firestore listener, so
/// the countdown stays accurate even when the session was pre-warmed some
/// seconds earlier. See QrDisplayScreen.
class HandshakeSession {
  const HandshakeSession({required this.url, required this.sessionId});

  final String url;
  final String sessionId;
}
