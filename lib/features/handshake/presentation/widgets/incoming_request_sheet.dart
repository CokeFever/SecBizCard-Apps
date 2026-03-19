import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';

class IncomingRequestSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(ContextType, bool) onApprove;
  final VoidCallback onDecline;

  const IncomingRequestSheet({
    super.key,
    required this.data,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  State<IncomingRequestSheet> createState() => _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends State<IncomingRequestSheet> {
  UserProfile? _receiverProfile;
  ContextType _selectedContext = ContextType.business;
  bool _saveToContacts = true;
  String _timeRemaining = "";
  Timer? _timer;

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
    Timestamp? timestamp = widget.data['expiresAt'] as Timestamp?;
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

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}
