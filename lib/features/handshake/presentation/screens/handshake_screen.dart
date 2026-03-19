import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/core/presentation/widgets/user_profile_avatar.dart';

import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_history_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';
import 'package:secbizcard/features/profile/domain/user_profile_extensions.dart';

class HandshakeScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const HandshakeScreen({required this.sessionId, super.key});

  @override
  ConsumerState<HandshakeScreen> createState() => _HandshakeScreenState();
}

class _HandshakeScreenState extends ConsumerState<HandshakeScreen> {
  bool _isRequesting = false;
  bool _requestSent = false;
  bool _hasLoggedContact = false; // prevent duplicate history entries
  UserProfile? _receivedProfile;
  String? _error;

  Timer? _timer;
  String _timeRemaining = "10:00";
  bool _expired = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimer(Timestamp? expiresAt) {
    if (expiresAt == null) return;

    final now = DateTime.now();
    final expiry = expiresAt.toDate();
    final diff = expiry.difference(now);

    if (diff.isNegative) {
      if (!_expired && mounted) {
        // Deferred update to avoid 'setState() called during build'
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _expired = true);
        });
      }
      return;
    }

    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final currentDiff = expiry.difference(DateTime.now());
      if (currentDiff.isNegative) {
        timer.cancel();
        setState(() {
          _expired = true;
          _timeRemaining = "00:00";
        });
        return;
      }

      final minutes = currentDiff.inMinutes.toString().padLeft(2, '0');
      final seconds = (currentDiff.inSeconds % 60).toString().padLeft(2, '0');

      setState(() {
        _timeRemaining = "$minutes:$seconds";
      });
    });
  }

  void _abort() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _sendRequest() async {
    setState(() {
      _isRequesting = true;
    });

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() => _error = "Not authenticated");
      return;
    }

    final myProfileRepo = ref.read(profileRepositoryProvider);
    final myProfileEither = await myProfileRepo.getUser(user.uid);

    final myProfileLimited = myProfileEither.fold(
      (l) => {'displayName': user.displayName ?? 'Guest', 'uid': user.uid},
      (p) => {
        'displayName': p.displayName,
        'uid': p.uid,
        'photoUrl': p.photoUrl, // Include photo so the approver can see it
        'title': p.title,
        'company': p.company,
        'createdAt': p.createdAt.toIso8601String(),
        'isOnboardingComplete': p.isOnboardingComplete,
      },
    );

    final repo = ref.read(handshakeRepositoryProvider);
    final result = await repo.requestHandshake(
      widget.sessionId,
      myProfileLimited,
    );

    result.fold(
      (l) {
        setState(() {
          _error = l.message;
          _isRequesting = false;
        });
      },
      (r) {
        setState(() {
          _requestSent = true;
          _isRequesting = false;
        });
      },
    );
  }

  void _onSaveContactPressed() async {
    if (_receivedProfile == null) return;

    // 1. Save Contact
    final contactsRepo = ref.read(contactsRepositoryProvider);
    final result = await contactsRepo.saveContactLocally(_receivedProfile!);

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${failure.message}')),
        );
      },
      (_) async {
        // Invalidate cache manually since repo doesn't do it anymore
        ref.invalidate(savedContactsProvider);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact Saved!')));

        // 2. Ask (Dialog) to Share Back
        final sharedBack = await _showShareBackDialog();
        if (sharedBack) {
          await _showContextSelectionSheet();
        }

        // 3. Navigate back to Contacts list
        if (mounted) {
          context.go('/home');
        }
      },
    );
  }

  Future<bool> _showShareBackDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Share Back?'),
          content: const Text('Do you want to share your contact info back?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showContextSelectionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ShareBackContextSheet(
        onShare: (contextType) async {
          Navigator.pop(context); // Close sheet
          await _performShareBack(contextType);
        },
      ),
    );
  }

  Future<void> _performShareBack(ContextType contextType) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final profileRepo = ref.read(profileRepositoryProvider);
    final userResult = await profileRepo.getUser(user.uid);
    UserProfile? myProfile;
    userResult.fold((l) => null, (r) => myProfile = r);

    if (myProfile == null) return;

    // Filter payload based on contextType selected by user
    final payload = myProfile!.filterForContext(contextType);

    final repo = ref.read(handshakeRepositoryProvider);
    final result = await repo.returnHandshake(widget.sessionId, payload);

    if (!mounted) return;

    result.fold(
      (l) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share: ${l.message}'))),
      (r) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Info Shared Back!'))),
    );
  }

  /// Log the received contact to local notification history (requester side).
  void _logReceivedContact(Map<String, dynamic> payload, String sessionId) {
    if (_hasLoggedContact) return; // Only log once
    _hasLoggedContact = true;

    try {
      final profile = UserProfile.fromJson(payload);
      final historyRepo = ref.read(handshakeHistoryRepositoryProvider);
      historyRepo.logRequest(
        HandshakeHistoryRecord(
          sessionId: sessionId,
          senderUid: profile.uid,
          senderName: profile.displayName,
          photoUrl: profile.photoUrl,
          status: HandshakeRequestStatus.approved,
          timestamp: DateTime.now(),
        ),
      );
      ref.invalidate(handshakeHistoryProvider);
    } catch (e) {
      debugPrint('[HandshakeScreen] Failed to log contact: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If expired locally, show invalid UI early?
    // Or prefer server status "expired".

    final repo = ref.watch(handshakeRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exchange Info'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _abort),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: repo.listenToSession(widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doc = snapshot.data!;
          if (!doc.exists) {
            return const Center(child: Text('Invalid or Expired Link'));
          }

          final data = doc.data()!;
          final status = data['status'] as String? ?? 'WAITING';

          // Update timer
          if (data['expiresAt'] is Timestamp) {
            _updateTimer(data['expiresAt'] as Timestamp);
          }

          if (_expired) {
            return _buildExpiredUI();
          }

          if (_receivedProfile != null) {
            return _buildSuccessUI();
          }

          if (status == 'APPROVED') {
            final payload = data['payload'] as Map<String, dynamic>?;
            if (payload != null) {
              // Log this to local notification history (requester side)
              _logReceivedContact(payload, widget.sessionId);
              try {
                return _buildDataReceivedUI(payload);
              } catch (e) {
                return Center(child: Text('Error parsing data: $e'));
              }
            }
          }

          if (status == 'REJECTED') {
            return _buildRejectedUI();
          }

          if (_requestSent || status == 'REQUESTED') {
            return _buildRequestSentUI();
          }

          // Initial State: Found Secure Link
          return _buildFoundLinkUI();
        },
      ),
    );
  }

  Widget _buildTimerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            _timeRemaining,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundLinkUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimerBadge(),
          const SizedBox(height: 32),
          const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
          const SizedBox(height: 32),
          Text(
            'Found Secure Link',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Request to exchange info?'),
          const SizedBox(height: 32),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          Row(
            // Buttons
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: _abort, child: const Text('Abort')),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isRequesting ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: _isRequesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Request'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSentUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimerBadge(),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Request Sent!',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Waiting for approval...'),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: _abort, child: const Text('Abort')),
        ],
      ),
    );
  }

  Widget _buildRejectedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Request Declined'),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: _abort, child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildExpiredUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_off, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Session Expired',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: _abort, child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildDataReceivedUI(Map<String, dynamic> payload) {
    final profile = UserProfile.fromJson(payload);

    // Store temporarily in case we need it, but we mostly use the payload here
    _receivedProfile ??= profile;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Info Received!',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          // Profile Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50], // Light background
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                UserProfileAvatar(
                  photoUrl: profile.photoUrl,
                  displayName: profile.displayName,
                  radius: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  profile.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (profile.title != null)
                  Text(
                    profile.title!,
                    style: GoogleFonts.inter(color: Colors.grey[700]),
                  ),
                if (profile.company != null)
                  Text(
                    profile.company!,
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 48),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _abort,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Abort'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onSaveContactPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Contact'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessUI() {
    return _buildDataReceivedUI(_receivedProfile!.toJson());
  }
}

class _ShareBackContextSheet extends StatefulWidget {
  final Function(ContextType) onShare;
  const _ShareBackContextSheet({required this.onShare});

  @override
  State<_ShareBackContextSheet> createState() => _ShareBackContextSheetState();
}

class _ShareBackContextSheetState extends State<_ShareBackContextSheet> {
  ContextType _selectedContext = ContextType.business;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Context to Share',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ContextType>(
            segments: const [
              ButtonSegment(
                value: ContextType.business,
                label: Text('Business'),
                icon: Icon(Icons.business),
              ),
              ButtonSegment(
                value: ContextType.social,
                label: Text('Social'),
                icon: Icon(Icons.people),
              ),
              ButtonSegment(
                value: ContextType.lite,
                label: Text('Lite'),
                icon: Icon(Icons.person_outline),
              ),
            ],
            selected: {_selectedContext},
            onSelectionChanged: (newSelection) {
              setState(() {
                _selectedContext = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onShare(_selectedContext),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Share'),
            ),
          ),
        ],
      ),
    );
  }
}
