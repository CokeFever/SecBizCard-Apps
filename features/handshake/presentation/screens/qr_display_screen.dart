import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:secbizcard/features/handshake/data/handshake_repository.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/domain/user_profile_extensions.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';

class QrDisplayScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const QrDisplayScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen>
    with AutomaticKeepAliveClientMixin {
  String? _qrUrl;
  String? _sessionId;
  bool _isLoading = true;
  String? _error;

  // Countdown timer
  Timer? _countdownTimer;
  int _remainingSeconds = 600; // 10 minutes
  static const int _qrValidityDuration = 600;

  StreamSubscription? _sessionSubscription;
  bool _showingRequestDialog = false;
  bool _batchApproval = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _generateQrCode();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _remainingSeconds = _qrValidityDuration;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _remainingSeconds--;

      if (_remainingSeconds <= 0) {
        timer.cancel();
        // Auto-regenerate when expired
        // Reset Batch Approval to Off
        if (mounted) {
          setState(() => _batchApproval = false);
        }
        _generateQrCode();
        return;
      }

      // Only rebuild if widget is visible (not hidden by IndexedStack)
      if (mounted) {
        setState(() {});
      }
    });
  }

  String get _formattedCountdown {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _generateQrCode() async {
    final currentUser = ref.read(authRepositoryProvider).getCurrentUser();

    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _error = 'You must be signed in to share your info.';
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _sessionId = null;
    });

    _sessionSubscription?.cancel();

    final repository = ref.read(handshakeRepositoryProvider);
    // No context selected initially
    final result = await repository.createHandshakeSession(
      batchApproval: _batchApproval,
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (url) {
        // Extract sessionId from URL for listening
        // Format: https://ixo.app/{hash}
        final uri = Uri.parse(url);
        final sessionId = uri.pathSegments.isNotEmpty
            ? uri.pathSegments.last
            : null;

        setState(() {
          _qrUrl = url;
          _sessionId = sessionId;
          _isLoading = false;
          _error = null;
        });
        _startCountdown();

        if (sessionId != null) {
          _listenToSession(sessionId);
        }
      },
    );
  }

  void _manualRefresh() {
    setState(() => _batchApproval = false);
    _generateQrCode();
  }

  void _listenToSession(String sessionId) {
    final repository = ref.read(handshakeRepositoryProvider);
    _sessionSubscription = repository.listenToSession(sessionId).listen((
      snapshot,
    ) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;

      if (status == 'REQUESTED' && !_showingRequestDialog) {
        // Show approval dialog!
        _showingRequestDialog = true;
        _showIncomingRequestDialog(data);
      } else if (status == 'RETURNED') {
        // Reciprocal exchange completed!
        // Show dialog to save the returned contact info
        // Check if we already showed it to avoid loops?
        // Data usually has 'returnPayload'
        _showIncomingReturnDialog(data);
      }
    });
  }

  void _showIncomingReturnDialog(Map<String, dynamic> data) async {
    final returnPayload = data['returnPayload'] as Map<String, dynamic>?;
    if (returnPayload == null) return;

    if (_showingRequestDialog) {
      // If we are still showing request dialog (race condition?), close it?
      // Or maybe the request dialog was closed when we approved.
      // Usually approval closes dialog.
    }

    // Check if duplicate dialog... For simplicity, allow for now.

    UserProfile? returnProfile;
    try {
      returnProfile = UserProfile.fromJson(returnPayload);
    } catch (_) {
      // Failed to parse return profile, ignore
    }

    if (returnProfile == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Info Shared Back!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('${returnProfile!.displayName} also shared their info.'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final contactsRepo = ref.read(contactsRepositoryProvider);
                  await contactsRepo.saveContactLocally(returnProfile!);
                  // Invalidate cache
                  ref.invalidate(savedContactsProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contact Saved!')),
                    );
                    _resetState(); // Reset for next handshake
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save to Contacts'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetState();
              },
              child: const Text('Close'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _resetState() {
    // Logic to reset for a new session or keep current?
    // For now, simple reset to allow new generation.
    setState(() {
      _sessionId = null;
      _qrUrl = null;
      _generateQrCode();
    });
  }

  void _approveRequest(
    ContextType contextType,
    UserProfile? receiverProfile,
    bool saveContact,
  ) async {
    if (_sessionId == null) return;

    // Save contact if requested
    if (saveContact && receiverProfile != null) {
      final contactsRepo = ref.read(contactsRepositoryProvider);
      await contactsRepo.saveContactLocally(receiverProfile);
      // Invalidate cache
      ref.invalidate(savedContactsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${receiverProfile.displayName} to contacts'),
          ),
        );
      }
    }

    // Prepare payload
    final user = ref
        .read(authRepositoryProvider)
        .getCurrentUser(); // Basic auth user
    if (user == null) {
      // Reject handshake since we can't proceed
      await _rejectWithError('Not authenticated');
      return;
    }

    // Use userProfileProvider which auto-creates profile if not exists
    final fullProfile = await ref.read(userProfileProvider.future);

    if (fullProfile == null) {
      // Reject handshake and notify user
      await _rejectWithError('Please complete your profile first');
      return;
    }

    // Filter profile based on context
    final payload = _filterProfileForContext(fullProfile, contextType);

    final handshakeRepo = ref.read(handshakeRepositoryProvider);
    final result = await handshakeRepo.respondToHandshake(
      _sessionId!,
      accept: true,
      encryptedPayload: payload,
    );

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${failure.message}')));
        }
      },
      (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Info Shared Successfully!')),
          );
        }
      },
    );
  }

  Future<void> _rejectWithError(String errorMessage) async {
    if (_sessionId == null) return;

    final handshakeRepo = ref.read(handshakeRepositoryProvider);
    await handshakeRepo.respondToHandshake(_sessionId!, accept: false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Share'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showIncomingRequestDialog(Map<String, dynamic> data) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _IncomingRequestSheet(
        data: data,
        onApprove: (contextType, saveContacts) {
          Navigator.pop(context);
          // Parse profile again for approval logic (or pass it back)
          // Actually we need the profile to approve.
          // Let's make onApprove pass the profile if possible or just handle logic here.
          // Easier to keep logic in parent.
          // We'll re-parse or pass it.
          final receiverProfileMap =
              data['receiverProfile'] as Map<String, dynamic>?;
          UserProfile? receiverProfile;
          if (receiverProfileMap != null) {
            try {
              receiverProfile = UserProfile.fromJson(receiverProfileMap);
            } catch (_) {}
          }

          _approveRequest(contextType, receiverProfile, saveContacts);
        },
        onDecline: () {
          Navigator.pop(context);
          _rejectRequest();
        },
      ),
    ).whenComplete(() {
      _showingRequestDialog = false;
    });
  }

  void _rejectRequest() async {
    if (_sessionId == null) return;
    final handshakeRepo = ref.read(handshakeRepositoryProvider);
    await handshakeRepo.respondToHandshake(_sessionId!, accept: false);
  }

  Map<String, dynamic> _filterProfileForContext(
    UserProfile user,
    ContextType type,
  ) {
    // Determine which context type we are currently sharing.
    // If this screen's widget.encodedData contains contextType, use it?
    // Actually, QrDisplayScreen just displays. The generation happens in _generateQrCode.
    // However, the prompt implies we might want to change *what* we share.
    // But currently _generateQrCode uses the FULL session ID which links to a session document.
    // Wait, Handshake logic: The initiator creates a session. The QR encodes the session ID.
    // The *initiator* also uploads their profile to the session document?
    // Let's check _generateQrCode.

    // Ah, wait. The prompt says "Filter field".
    // If QR code contains DIRECT data (not session ID), filtering matters here.
    // But this app seems to use Session ID in QR.
    // Let's assume this method is used when we upload our data to the session init.

    // Looking at file: _filterProfileForContext is unused in previous snippet or call sites not visible?
    // Let's check where it's called. It's likely called before creating the session.

    return user.filterForContext(type);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final content = Center(
      child: _isLoading
          ? const CircularProgressIndicator()
          : _error != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $_error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _generateQrCode,
                  child: const Text('Retry'),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan to Exchange',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrUrl!,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Batch Approval Toggle
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      // Transparent background
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batch Approval',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            Text(
                              _batchApproval
                                  ? 'Approve first request for all'
                                  : 'Approve each request manually',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _batchApproval,
                          onChanged: (val) {
                            setState(() {
                              _batchApproval = val;
                              _generateQrCode();
                            });
                          },
                          activeThumbColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? Colors.blue[200]
                              : Theme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _remainingSeconds <= 180
                            ? Colors.red
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Resets in $_formattedCountdown',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _remainingSeconds <= 180
                              ? Colors.red
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Refresh button enabled after 60s (remaining <= 240s)
                      IconButton(
                        onPressed: (_remainingSeconds <= 420 && !_isLoading)
                            ? _manualRefresh
                            : null,
                        icon: const Icon(Icons.refresh),
                        tooltip: _remainingSeconds > 420
                            ? 'Available in ${_remainingSeconds - 420}s'
                            : 'Refresh QR Code',
                        color: Theme.of(context).primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // URL Display with Copy Button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _qrUrl!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _qrUrl!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('URL copied to clipboard'),
                              ),
                            );
                          },
                          tooltip: 'Copy URL',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Share',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: content,
    );
  }
}

class _IncomingRequestSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(ContextType, bool) onApprove;
  final VoidCallback onDecline;

  const _IncomingRequestSheet({
    required this.data,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  State<_IncomingRequestSheet> createState() => _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends State<_IncomingRequestSheet> {
  ContextType _selectedContext = ContextType.business;
  bool _saveToContacts = true;
  UserProfile? _receiverProfile;

  Timer? _timer;
  String _timeRemaining = "";

  @override
  void initState() {
    super.initState();
    _parseProfile();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _parseProfile() {
    final receiverProfileMap =
        widget.data['receiverProfile'] as Map<String, dynamic>?;
    if (receiverProfileMap != null) {
      try {
        _receiverProfile = UserProfile.fromJson(receiverProfileMap);
      } catch (_) {}
    }
  }

  void _startTimer() {
    // Assuming 'expiresAt' or 'requestedAt' + 5 mins?
    // Let's use session expiry if available //
    Timestamp? timestamp = widget.data['expiresAt'] as Timestamp?;
    // If expiresAt is null, try requestedAt + 5 mins
    if (timestamp == null) {
      final reqAt = widget.data['requestedAt'] as Timestamp?;
      if (reqAt != null) {
        timestamp = Timestamp.fromMillisecondsSinceEpoch(
          reqAt.millisecondsSinceEpoch + 5 * 60 * 1000,
        );
      }
    }

    if (timestamp == null) return;

    final expiry = timestamp.toDate();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final diff = expiry.difference(DateTime.now());
      if (diff.isNegative) {
        timer.cancel();
        setState(() => _timeRemaining = "Expired");
        return;
      }

      final minutes = diff.inMinutes.toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

      setState(() {
        _timeRemaining = "$minutes:$seconds";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _receiverProfile?.displayName ?? 'Unknown User';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Incoming Request',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_timeRemaining.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _timeRemaining,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('$name wants to exchange contact info.'),
          if (_receiverProfile?.title != null)
            Text(
              _receiverProfile!.title!,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          const SizedBox(height: 24),

          if (_receiverProfile != null)
            CheckboxListTile(
              value: _saveToContacts,
              onChanged: (val) {
                setState(() => _saveToContacts = val ?? true);
              },
              title: const Text('Add to my contacts'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),

          const SizedBox(height: 12),
          Text(
            'Choose info to share:',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

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

          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      widget.onApprove(_selectedContext, _saveToContacts),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
