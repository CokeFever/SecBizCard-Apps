import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:secbizcard/features/handshake/data/handshake_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_history_repository.dart';
import 'package:secbizcard/features/handshake/presentation/widgets/incoming_request_sheet.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile_extensions.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/core/presentation/widgets/user_profile_avatar.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

class HandshakeHistoryScreen extends ConsumerWidget {
  const HandshakeHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(handshakeHistoryProvider);
    final repository = ref.read(handshakeHistoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          historyAsync.when(
            data: (reports) => IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: reports.isEmpty
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear History?'),
                          content: const Text(
                            'This will delete all handshake records.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await repository.clearHistory();
                        ref.invalidate(handshakeHistoryProvider);
                      }
                    },
              tooltip: 'Clear History',
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(handshakeHistoryProvider);
            },
            child: ListView.separated(
              itemCount: reports.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final report = reports[index];
                return ListTile(
                  leading: UserProfileAvatar(
                    photoUrl: report.photoUrl,
                    displayName: report.senderName ?? '?',
                    radius: 20,
                  ),
                  title: Text(
                    report.senderName ?? 'Unknown User',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(report.timestamp),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  trailing: Builder(
                    builder: (context) {
                      var status = report.status;
                      // Logic for Expiry (10 minutes)
                      if (status == HandshakeRequestStatus.pending &&
                          DateTime.now().difference(report.timestamp).inMinutes > 10) {
                        status = HandshakeRequestStatus.expired;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.name.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () async {
                    var status = report.status;
                    final isExpired = status == HandshakeRequestStatus.pending &&
                        DateTime.now().difference(report.timestamp).inMinutes > 10;
                    
                    if (status != HandshakeRequestStatus.pending || isExpired) return;
                    if (report.receiverProfileJson == null) return;

                    final data = jsonDecode(report.receiverProfileJson!) as Map<String, dynamic>;
                    
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => IncomingRequestSheet(
                        data: data,
                        onApprove: (contextType, saveContacts) async {
                          Navigator.pop(context);
                          final handshakeRepo = ref.read(handshakeRepositoryProvider);
                          
                          // Get current user's profile
                          final fullProfile = await ref.read(userProfileProvider.future);
                          if (fullProfile == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please complete your profile first')),
                              );
                            }
                            return;
                          }

                          // Filter profile based on context
                          final payload = fullProfile.filterForContext(contextType);
                          
                          final result = await handshakeRepo.respondToHandshake(
                            report.sessionId,
                            accept: true,
                            encryptedPayload: payload,
                          );

                          result.fold(
                            (failure) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: ${failure.message}')),
                                );
                              }
                            },
                            (_) async {
                              // If saveContacts is true, save the receiver's contact info
                              if (saveContacts) {
                                final receiverProfileMap = data['receiverProfile'] as Map<String, dynamic>?;
                                if (receiverProfileMap != null) {
                                  try {
                                    final receiverProfile = UserProfile.fromJson(receiverProfileMap);
                                    await ref.read(contactsRepositoryProvider).saveContactLocally(receiverProfile);
                                  } catch (e) {
                                    debugPrint('Failed to save contact: $e');
                                  }
                                }
                              }

                              // Update local history status
                              repository.updateStatus(
                                report.sessionId,
                                report.senderUid,
                                HandshakeRequestStatus.approved,
                              );
                              ref.invalidate(handshakeHistoryProvider);
                              ref.invalidate(pendingHandshakeCountProvider);
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Approved!')),
                                );
                              }
                            },
                          );
                        },
                        onDecline: () async {
                          Navigator.pop(context);
                          final handshakeRepo = ref.read(handshakeRepositoryProvider);
                          await handshakeRepo.respondToHandshake(report.sessionId, accept: false);
                          
                          // Update local history status
                          repository.updateStatus(
                            report.sessionId,
                            report.senderUid,
                            HandshakeRequestStatus.rejected,
                          );
                          ref.invalidate(handshakeHistoryProvider);
                          ref.invalidate(pendingHandshakeCountProvider);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Color _getStatusColor(HandshakeRequestStatus status) {
    switch (status) {
      case HandshakeRequestStatus.approved:
        return Colors.green;
      case HandshakeRequestStatus.rejected:
        return Colors.red;
      case HandshakeRequestStatus.pending:
        return Colors.orange;
      case HandshakeRequestStatus.missed:
        return Colors.grey;
      case HandshakeRequestStatus.expired:
        return Colors.brown;
    }
  }
}


