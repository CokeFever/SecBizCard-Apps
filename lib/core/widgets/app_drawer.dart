import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/core/config/theme_controller.dart';
import 'package:secbizcard/core/widgets/profile_avatar.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_drawer.g.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.getCurrentUser();
    final profileRepo = ref.watch(profileRepositoryProvider);

    return Drawer(
      child: Column(
        children: [
          if (user != null)
            FutureBuilder(
              future: profileRepo.getUser(user.uid),
              builder: (context, snapshot) {
                final profile = snapshot.data?.getRight().toNullable();
                return UserAccountsDrawerHeader(
                  accountName: Text(
                    profile?.displayName ?? user.displayName ?? 'User',
                  ),
                  accountEmail: Text(user.email ?? ''),
                  currentAccountPicture: ProfileAvatar(
                    profile: profile,
                    radius: 36, // Appropriate for UserAccountsDrawerHeader
                    backgroundColor: Colors.white24,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                );
              },
            )
          else
            const DrawerHeader(child: Center(child: Text('Not Logged In'))),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context);
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Manage Contexts'),
            onTap: () async {
              if (user != null) {
                // Use userProfileProvider which has auto-create logic
                final profile = await ref.read(userProfileProvider.future);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (profile != null) {
                  context.push('/context-settings', extra: profile);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error loading profile')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Backup & Restore'),
            onTap: () {
              Navigator.pop(context);
              context.push('/backup');
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import vCard'),
            onTap: () {
              Navigator.pop(context);
              context.push('/import-vcard');
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Appearance',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final mode =
                  ref.watch(themeControllerProvider).valueOrNull ??
                  ThemeMode.system;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Auto', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.brightness_auto, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.light_mode, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.dark_mode, size: 16),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (newSelection) {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setThemeMode(newSelection.first);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await authRepo.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
          // Privacy, Terms & Version — single row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('https://ixo.app/privacy'), mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'Privacy',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('https://ixo.app/eula'), mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'Terms',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
                const Spacer(),
                FutureBuilder(
                  future: ref.read(packageInfoProvider.future),
                  builder: (context, snapshot) {
                    final packageInfo = snapshot.data;
                    if (packageInfo == null) return const SizedBox.shrink();
                    return Text(
                      'v${packageInfo.version}',
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                    );
                  },
                ),
              ],
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@riverpod
Future<PackageInfo> packageInfo(Ref ref) {
  return PackageInfo.fromPlatform();
}
