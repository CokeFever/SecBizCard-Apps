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
import 'package:secbizcard/generated/l10n/app_localizations.dart';

part 'app_drawer.g.dart';

class AppDrawer extends ConsumerWidget {
  /// When true, the drawer is rendered permanently docked (inline side panel)
  /// rather than as a modal overlay. In docked mode, tapping an item must NOT
  /// call Navigator.pop (there's no overlay to dismiss — popping would remove
  /// the underlying route), so [_dismiss] becomes a no-op.
  final bool isDocked;

  const AppDrawer({super.key, this.isDocked = false});

  /// Closes the drawer when it's a modal overlay; no-op when docked.
  void _dismiss(BuildContext context) {
    if (!isDocked) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authRepo = ref.watch(authRepositoryProvider);
    final user = authRepo.getCurrentUser();
    final profileRepo = ref.watch(profileRepositoryProvider);

    return Drawer(
      // Docked (permanent side panel): drop the modal drawer's rounded corner
      // and elevation so it reads as a flat left column, not a floating sheet.
      elevation: isDocked ? 0 : null,
      shape: isDocked
          ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero)
          : null,
      child: Column(
        children: [
          if (user != null)
            FutureBuilder(
              future: profileRepo.getUser(user.uid),
              builder: (context, snapshot) {
                final profile = snapshot.data?.getRight().toNullable();
                return UserAccountsDrawerHeader(
                  accountName: Text(
                    profile?.displayName ??
                        user.displayName ??
                        l10n.drawerDefaultUser,
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
            DrawerHeader(child: Center(child: Text(l10n.drawerNotLoggedIn))),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.drawerMyProfile),
            onTap: () {
              _dismiss(context);
              context.push('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(l10n.drawerManageContexts),
            onTap: () async {
              if (user != null) {
                // Use userProfileProvider which has auto-create logic
                final profile = await ref.read(userProfileProvider.future);
                if (!context.mounted) return;
                _dismiss(context);
                if (profile != null) {
                  context.push('/context-settings', extra: profile);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.drawerErrorLoadingProfile)),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: Text(l10n.drawerBackupRestore),
            onTap: () {
              _dismiss(context);
              context.push('/backup');
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(l10n.drawerAiRecognition),
            onTap: () {
              _dismiss(context);
              context.push('/ocr-settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(l10n.drawerImportVcard),
            onTap: () {
              _dismiss(context);
              context.push('/import-vcard');
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.drawerAppearance,
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
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l10n.drawerThemeAuto,
                          style: const TextStyle(fontSize: 12)),
                      icon: const Icon(Icons.brightness_auto, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l10n.drawerThemeLight,
                          style: const TextStyle(fontSize: 12)),
                      icon: const Icon(Icons.light_mode, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l10n.drawerThemeDark,
                          style: const TextStyle(fontSize: 12)),
                      icon: const Icon(Icons.dark_mode, size: 16),
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
            title: Text(l10n.drawerLogout,
                style: const TextStyle(color: Colors.red)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.drawerConfirmLogoutTitle),
                  content: Text(l10n.drawerConfirmLogoutBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: Text(l10n.drawerLogout),
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
                    _dismiss(context);
                    launchUrl(Uri.parse('https://ixo.app/privacy'), mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    l10n.drawerLinkPrivacy,
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ),
                GestureDetector(
                  onTap: () {
                    _dismiss(context);
                    launchUrl(Uri.parse('https://ixo.app/eula'), mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    l10n.drawerLinkTerms,
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11, decoration: TextDecoration.underline),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ),
                GestureDetector(
                  onTap: () {
                    // Pass the app's current locale so the web guide opens in
                    // the reader's language (?lang=). The web page normalizes
                    // the value (e.g. zh_TW → Traditional) and falls back to
                    // English for anything it doesn't recognize.
                    final locale = Localizations.localeOf(context);
                    final lang = locale.countryCode != null &&
                            locale.countryCode!.isNotEmpty
                        ? '${locale.languageCode}_${locale.countryCode}'
                        : locale.languageCode;
                    _dismiss(context);
                    launchUrl(
                      Uri.parse('https://ixo.app/guide?lang=$lang'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(
                    l10n.drawerLinkGuide,
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
