import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/core/database/database_helper.dart';

import 'package:secbizcard/core/widgets/verification_badge.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:secbizcard/features/verification/presentation/screens/email_verification_screen.dart';
import 'package:secbizcard/features/verification/presentation/screens/phone_verification_screen.dart';
import 'package:secbizcard/core/utils/field_formatter.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch profile data
    // In a real app, consider using a FutureProvider or StreamProvider for this
    // to handle loading/error states better. For sprint 1, we keep it simple or fetch on init.
    // However, since we sync on login, we might already have it or can fetch it now.
    // A better pattern is a UserProfileProvider. Let's assume we fetch it here or use a provider.

    // For MVP Sprint 1, let's just display what we have from Auth + fetch from Firestore
    // But since we can't easily make build async, we usually use a provider.
    // Let's create a temporary FutureBuilder for simplicity or just a provider call.

    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildAvatar(ref, profile),
                const SizedBox(height: 24),
                Text(
                  profile.displayName,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (profile.title != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile.title!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (profile.email != null && profile.email!.isNotEmpty)
                  _buildInfoTileWithVerification(
                    Icons.email,
                    profile.email!,
                    isVerified:
                        profile.emailVerified || _isVerifiedAuthAccount(profile),
                    verificationType: VerificationType.email,
                    verifiedAt: profile.emailVerifiedAt,
                    businessDomain: profile.businessEmailDomain,
                  ),
                if (profile.phone != null)
                  _buildInfoTileWithVerification(
                    Icons.phone,
                    profile.phone!,
                    isVerified: profile.phoneVerified,
                    verificationType: VerificationType.phone,
                    verifiedAt: profile.phoneVerifiedAt,
                  ),
                if (profile.company != null)
                  _buildInfoTile(Icons.business, profile.company!),

                // Custom Fields Section
                if (profile.customFields.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...profile.customFields.entries.map((entry) {
                    final isEmailField = entry.key.toLowerCase().contains(
                      'email',
                    );
                    final isLoginEmail =
                        isEmailField && entry.value == (profile.email ?? '');

                    return _buildInfoTile(
                      FieldFormatter.getIcon(entry.key),
                      entry.value,
                      label: FieldFormatter.formatLabel(entry.key),
                      showVerificationHint: false, // Hidden until mechanism is ready
                      onVerifyTap: null, // Disabled for secondary emails
                    );
                  }),
                ],

                const SizedBox(height: 32),
                // Verification Section
                if (!profile.phoneVerified ||
                    (!profile.emailVerified && !_isVerifiedAuthAccount(profile)))
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Verify your information',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!profile.emailVerified &&
                            !_isVerifiedAuthAccount(profile))
                          _buildVerificationButton(
                            context,
                            'Verify Email',
                            Icons.email,
                            () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const EmailVerificationScreen(),
                                ),
                              );
                            },
                          ),
                        if (!profile.phoneVerified)
                          _buildVerificationButton(
                            context,
                            'Verify Phone',
                            Icons.phone,
                            () async {
                              await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PhoneVerificationScreen(
                                    initialPhoneNumber: profile.phone,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/edit-profile', extra: profile);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => _showDeleteAccountDialog(context, ref),
                  child: Text(
                    'Delete Account',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(WidgetRef ref, UserProfile profile) {
    final driveRepo = ref.read(driveRepositoryProvider);

    // Priority: avatarDriveFileId > photoUrl (Google Sign-In) > placeholder
    if (profile.avatarDriveFileId != null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: CachedNetworkImageProvider(
          driveRepo.getFileUrl(profile.avatarDriveFileId!),
        ),
      );
    } else if (profile.photoUrl != null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: profile.photoUrl!.startsWith('http')
            ? CachedNetworkImageProvider(profile.photoUrl!)
            : FileImage(File(profile.photoUrl!)) as ImageProvider,
      );
    } else {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.person, size: 50, color: Colors.grey),
      );
    }
  }

  Widget _buildInfoTile(
    IconData icon,
    String text, {
    String? label,
    bool showVerificationHint = false,
    VoidCallback? onVerifyTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null)
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                Text(text, style: GoogleFonts.inter(fontSize: 16)),
              ],
            ),
          ),
          if (showVerificationHint)
            GestureDetector(
              onTap: onVerifyTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 12,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verify',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Removed duplicated _getIconForCustomField as we use FieldFormatter.getIcon


  Widget _buildInfoTileWithVerification(
    IconData icon,
    String text, {
    required bool isVerified,
    required VerificationType verificationType,
    DateTime? verifiedAt,
    String? businessDomain,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 16))),
          const SizedBox(width: 8),
          if (isVerified)
            CompactVerificationBadge(
              type: verificationType,
              isVerified: isVerified,
            ),
          if (businessDomain != null) const SizedBox(width: 4),
          if (businessDomain != null)
            const CompactVerificationBadge(
              type: VerificationType.business,
              isVerified: true,
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: GoogleFonts.inter(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 40),
          side: BorderSide(color: Colors.orange.shade300),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
            const SizedBox(width: 8),
            const Text('Delete Account'),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all data. This action cannot be undone.\n\n'
          '⚠️ We strongly recommend using the Backup feature (in Settings) to export your contacts before deleting your account.\n\n'
          'You will need to re-authenticate to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[900]),
            child: const Text('Continue to Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Second confirmation
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'This is your last chance. Your account, profile, and all contacts will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[900]),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (finalConfirm != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Capture the navigator to safely pop the dialog later even if GoRouter redirects
    // and unmounts our current context.
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      await DatabaseHelper.instance.deleteAllData();
      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.deleteAccount();

      // Always dismiss the loading dialog
      if (navigator.canPop()) {
        navigator.pop();
      }

      result.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: ${failure.message}'), backgroundColor: Colors.red),
            );
          }
        },
        (_) {
          // GoRouter listener will handle the redirect to /login automatically 
          // when Firebase auth state changes. No need to manually context.go
        },
      );
    } catch (e) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isVerifiedAuthAccount(UserProfile profile) {
    if (profile.email == null) return false;
    return profile.email!.endsWith('@gmail.com') ||
        profile.email!.endsWith('@googlemail.com') ||
        profile.email!.endsWith('@privaterelay.appleid.com');
  }
}
