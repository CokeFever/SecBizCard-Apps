import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/core/config/theme_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:secbizcard/features/contacts/data/services/vcard_service.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';

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
                  currentAccountPicture: CircleAvatar(
                    backgroundImage: profile?.photoUrl != null
                        ? (profile!.photoUrl!.startsWith('http')
                              ? NetworkImage(profile.photoUrl!)
                              : FileImage(File(profile.photoUrl!))
                                    as ImageProvider)
                        : (user.photoURL != null
                              ? (user.photoURL!.startsWith('http')
                                    ? NetworkImage(user.photoURL!)
                                    : FileImage(File(user.photoURL!))
                                          as ImageProvider)
                              : null),
                    child: (profile?.photoUrl == null && user.photoURL == null)
                        ? const Icon(Icons.person)
                        : null,
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
            leading: const Icon(Icons.file_upload),
            title: const Text('Import vCard'),
            onTap: () async {
              // Pick file BEFORE closing drawer to keep context valid
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['vcf'],
              );

              if (!context.mounted) return;

              // Get all needed references BEFORE closing drawer (drawer context will be disposed)
              final navigatorContext = Navigator.of(context).context;
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              final contactsRepo = ref.read(contactsRepositoryProvider);
              void invalidateSavedContacts() =>
                  ref.invalidate(savedContactsProvider);

              Navigator.pop(context); // Close drawer after file picked

              if (result == null || result.files.single.path == null) {
                return; // User cancelled
              }

              try {
                final file = File(result.files.single.path!);
                final content = await file.readAsString();
                final contacts = VCardService.parse(content);

                if (contacts.isEmpty) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('No contacts found in vCard file'),
                    ),
                  );
                  return;
                }

                // Show preview dialog
                if (!navigatorContext.mounted) return;

                final shouldImport = await showDialog<bool>(
                  context: navigatorContext,
                  builder: (ctx) => AlertDialog(
                    title: Text('Import ${contacts.length} Contact(s)?'),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: contacts.length,
                        itemBuilder: (_, index) {
                          final c = contacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                c.displayName.isNotEmpty
                                    ? c.displayName[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(c.displayName),
                            subtitle: Text(
                              (c.email?.isNotEmpty == true)
                                  ? c.email!
                                  : (c.phone?.isNotEmpty == true
                                        ? c.phone!
                                        : 'No contact info'),
                            ),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Import'),
                      ),
                    ],
                  ),
                );

                if (shouldImport != true) return;

                // Import contacts
                int savedCount = 0;
                for (final contact in contacts) {
                  final saveResult = await contactsRepo.saveContactLocally(
                    contact,
                  );
                  if (saveResult.isRight()) savedCount++;
                }

                // Try to invalidate (may fail if ref is disposed, which is OK)
                try {
                  invalidateSavedContacts();
                } catch (_) {}

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Imported $savedCount contacts successfully'),
                    action: SnackBarAction(
                      label: 'View',
                      onPressed: () => router.go('/home?tab=1'),
                    ),
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Failed to import vCard: $e')),
                );
              }
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
