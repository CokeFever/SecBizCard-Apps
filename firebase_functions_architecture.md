# Firebase Cloud Functions Architecture

This document outlines the purpose and necessity of the 6 core Firebase Cloud Functions used in the SecBizCard application. These functions handle the entire lifecycle of a business card exchange (handshake) between two users, including edge cases for users who do not yet have the App installed.

All 6 functions play a critical and distinct role in the system.

---

## 1. Core App-to-App Exchange Flow (3 Functions)
These functions handle the standard flow when both users have the SecBizCard App installed.

### `createHandshakeSession` (onCall)
*   **Purpose:** Triggered when User A presses "Generate QR Code" in the App. It creates a new `handshakes` document in Firestore with a random UUID, a 6-digit PIN, and reserves the session for User A's outgoing profile.
*   **Necessity:** **Strictly Necessary**. This is the genesis of any connection.

### `requestHandshake` (onCall)
*   **Purpose:** Triggered when User B uses the App to scan User A's QR Code. It validates the session ID and PIN, checks for expiration, and updates the session status to `REQUESTED`. It also writes User B's basic profile (name, avatar) into the session so User A can see who is requesting the connection.
*   **Necessity:** **Strictly Necessary**. Acts as the verification layer for the receiver.

### `respondToHandshake` (onCall)
*   **Purpose:** Triggered when User A presses "Approve" or "Reject" on the incoming request screen. If approved, it changes the session status to `APPROVED`, which formally releases the full payload (User A's complete contact card) to User B.
*   **Necessity:** **Strictly Necessary**. Serves as the security and consent gatekeeper. Data is only released upon explicit approval.

---

## 2. Web-to-App Handoff Flow (2 Functions)
These functions handle the fallback flow when someone without the App scans the QR code using a standard camera, opening the Web interface (`ixo.app`).

### `savePendingSession` (onRequest / HTTP)
*   **Purpose:** When the Web interface is opened, it generates a device fingerprint and calls this API. This function saves the intended `sessionId` and the fingerprint in a temporary `pending_sessions` Firestore collection.
*   **Necessity:** **Strictly Necessary**. Allows users to register their "intent to scan" before they are redirected to download and install the App.

### `getPendingSession` (onCall)
*   **Purpose:** When the user subsequently installs and opens the Flutter App, the App generates the same device fingerprint and calls this API. The backend retrieves the previously stored `sessionId` from `pending_sessions` and deletes the temporary record.
*   **Necessity:** **Strictly Necessary**. Bridges the gap between the Web browser context and the native App context, enabling a seamless deep-linking experience post-installation.

---

## 3. Advanced Interactive Flow (1 Function)
This function enables bidirectional exchanges without requiring a second scan.

### `returnHandshake` (onCall)
*   **Purpose:** Triggered when User B, after successfully receiving User A's card, decides to "return the favor" and send their own card back. This function directly invokes Firebase Cloud Messaging (FCM) to send a silent data push notification containing User B's payload to User A's device.
*   **Necessity:** **Strictly Necessary**. Without this, "two-way exchange" features would require User A to generate a new QR code and User B to scan it, completely ruining the UX. This enables single-scan, mutual exchanges.
