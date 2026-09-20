import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/core/widgets/app_drawer.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/handshake/presentation/screens/qr_display_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/contacts_list_screen.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/handshake/data/handshake_history_repository.dart';
import 'package:secbizcard/core/services/notification_service.dart';
import 'package:secbizcard/core/services/backup_reminder_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;
  bool _isProcessingTap = false;

  // Ensures the backup reminder is evaluated at most once per app launch
  // (process lifetime), not on every navigation to /home. Because it lives in
  // memory it resets only on a true cold start — so a change made during a
  // session is only surfaced on the NEXT launch, never the current one.
  static bool _backupReminderCheckedThisLaunch = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _pages = [
      const QrDisplayScreen(showAppBar: false),
      const ContactsListScreen(showAppBar: false),
    ];

    // If starting on contacts tab, refresh the list
    if (_currentIndex == 1) {
      Future.microtask(() {
        if (mounted) {
          ref.invalidate(savedContactsProvider);
        }
      });
    }

    // Initialize notification service after home screen renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
      _maybeShowBackupReminder();
    });
  }

  /// Once per app launch, if the user has data with unbacked-up changes and
  /// hasn't snoozed this month, gently suggest a Google Drive backup. Purely
  /// local — never touches Drive/permissions.
  Future<void> _maybeShowBackupReminder() async {
    if (_backupReminderCheckedThisLaunch) return;
    _backupReminderCheckedThisLaunch = true;

    // Need a signed-in user with actual data. Load saved contacts (already
    // cached by the provider) to decide "hasData".
    final contactsResult =
        await ref.read(contactsRepositoryProvider).getSavedContacts();
    final hasData = contactsResult.fold((_) => false, (list) => list.isNotEmpty);
    if (!hasData) return;

    final reminder = ref.read(backupReminderServiceProvider);
    final shouldRemind = await reminder.shouldRemind(hasData: hasData);
    if (!shouldRemind || !mounted) return;

    await _showBackupReminderDialog(reminder);
  }

  Future<void> _showBackupReminderDialog(BackupReminderService reminder) async {
    var dontRemind = false;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Back up your contacts?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your contacts and card images are stored only on this device. '
                'We recommend backing them up to your own Google Drive so you '
                "don't lose them.",
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: dontRemind,
                onChanged: (v) => setLocal(() => dontRemind = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text("Don't remind me this month"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'later'),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'backup'),
              child: const Text('Back up now'),
            ),
          ],
        ),
      ),
    );

    // Honour the checkbox regardless of which button was tapped.
    if (dontRemind) {
      await reminder.snoozeThisMonth();
    }
    if (action == 'backup' && mounted) {
      context.push('/backup');
    }
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle navigation via router.go('/home?tab=1')
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _currentIndex = widget.initialTab;
      });
      // Refresh contacts if switching to contacts tab
      if (_currentIndex == 1) {
        ref.invalidate(savedContactsProvider);
      }
    }
  }

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_isProcessingTap || _currentIndex == index) return;

    _isProcessingTap = true;
    setState(() => _currentIndex = index);

    // If switching AWAY from contacts, stop searching + clear any multi-select
    if (index != 1) {
      ref.read(contactsSearchModeProvider.notifier).state = false;
      ref.read(contactsSearchQueryProvider.notifier).state = '';
      _searchController.clear();
      ref.read(contactsSelectionModeProvider.notifier).state = false;
      ref.read(contactsSelectedIdsProvider.notifier).state = {};
    } else {
      // Switching TO contacts - refresh the list
      ref.invalidate(savedContactsProvider);
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _isProcessingTap = false;
    });
  }

  /// The FAB action depends on which section is active:
  /// Share tab -> scan a QR code, Card tab -> scan a business card.
  void _onPrimaryAction(int forIndex) {
    if (forIndex == 0) {
      context.push('/qr-scanner');
    } else {
      context.push('/scan');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Single-pane everywhere — the layout is identical to phone on every
    // device (iPad included). The ONLY large-screen adaptation is that on a
    // wide landscape screen the hamburger Drawer is docked open beside the
    // content instead of hidden behind a menu button. This applies only to the
    // main shell (Share / Card); every pushed screen stays full-screen.
    return _buildCompactLayout(context);
  }

  /// True when the main shell should show the Drawer permanently docked to the
  /// left: only on large screens (tablet/iPad, >= medium) AND in landscape.
  /// Portrait and phones keep the modal hamburger drawer.
  bool _useDockedDrawer(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    return isLandscape && size.width >= Breakpoints.medium;
  }

  // ---------------------------------------------------------------------------
  // Shared AppBar (title + search field + contextual actions)
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(BuildContext context, {String? titleOverride}) {
    final theme = Theme.of(context);
    final isSearching = ref.watch(contactsSearchModeProvider);
    final selectionMode = ref.watch(contactsSelectionModeProvider);

    // Multi-select bar (contacts tab only) takes over the AppBar, mirroring how
    // search mode does. A close button exits; actions are the batch Export /
    // Share (Delete is deliberately NOT here — it stays single-item swipe).
    if (_currentIndex == 1 && selectionMode && titleOverride == null) {
      final count = ref.watch(contactsSelectedIdsProvider).length;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel selection',
          onPressed: _exitSelection,
        ),
        title: Text(
          '$count selected',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: _selectAllContacts,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: count == 0 ? null : _showExportOptions,
          ),
        ],
      );
    }

    return AppBar(
      title: (_currentIndex == 1 && isSearching && titleOverride == null)
          ? _buildSearchField(theme)
          : Text(
              titleOverride ?? (_currentIndex == 0 ? 'Share' : 'Card'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
      actions: _buildAppBarActions(context),
    );
  }

  // --- Multi-select helpers (contacts tab) ---------------------------------

  void _exitSelection() {
    ref.read(contactsSelectionModeProvider.notifier).state = false;
    ref.read(contactsSelectedIdsProvider.notifier).state = {};
  }

  void _selectAllContacts() {
    final all = ref.read(savedContactsProvider).valueOrNull ?? const [];
    ref.read(contactsSelectedIdsProvider.notifier).state =
        all.map((c) => c.uid).toSet();
  }

  /// Resolve the currently selected ids to full profiles (order-independent).
  List<UserProfile> _selectedProfiles() {
    final ids = ref.read(contactsSelectedIdsProvider);
    final all = ref.read(savedContactsProvider).valueOrNull ?? const [];
    return all.where((c) => ids.contains(c.uid)).toList();
  }

  /// Presents the three export choices for the current selection:
  /// text-only vCard, text + images (.zip), or Save to Google Contacts.
  Future<void> _showExportOptions() async {
    final count = _selectedProfiles().length;
    if (count == 0) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Export $count contact(s)',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Text only (vCard .vcf)'),
              subtitle: const Text('Contact fields, no card images'),
              onTap: () => Navigator.pop(ctx, 'vcf'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('Text + images (.zip)'),
              subtitle: const Text('Fields plus card photos, re-importable'),
              onTap: () => Navigator.pop(ctx, 'zip'),
            ),
            ListTile(
              leading: const Icon(Icons.import_export),
              title: const Text('Save to Google Contacts'),
              onTap: () => Navigator.pop(ctx, 'google'),
            ),
          ],
        ),
      ),
    );

    switch (choice) {
      case 'vcf':
        await _batchShareVCard();
        break;
      case 'zip':
        await _batchShareZip();
        break;
      case 'google':
        await _batchExportToGoogle();
        break;
    }
  }

  Future<void> _batchShareVCard() async {
    final profiles = _selectedProfiles();
    if (profiles.isEmpty) return;
    final service = ref.read(contactExportServiceProvider);
    try {
      await service.shareAsVCard(profiles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
    _exitSelection();
  }

  Future<void> _batchShareZip() async {
    final profiles = _selectedProfiles();
    if (profiles.isEmpty) return;
    final service = ref.read(contactExportServiceProvider);
    try {
      await service.shareAsZip(profiles);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
    _exitSelection();
  }

  Future<void> _batchExportToGoogle() async {
    final profiles = _selectedProfiles();
    if (profiles.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Exporting ${profiles.length} contact(s)…')),
    );
    final service = ref.read(contactExportServiceProvider);
    final result = await service.exportToGoogle(profiles);
    if (!mounted) return;
    final String msg;
    if (result.allOk) {
      msg = 'Exported ${result.succeeded} contact(s) to Google Contacts';
    } else if (result.succeeded == 0) {
      msg = 'Export failed: ${result.firstError ?? 'unknown error'}';
    } else {
      msg = 'Exported ${result.succeeded} of ${result.total}; '
          '${result.failed} failed';
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
    _exitSelection();
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.inter(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search contacts...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (v) =>
            ref.read(contactsSearchQueryProvider.notifier).state = v,
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context) {
    final isSearching = ref.watch(contactsSearchModeProvider);
    return [
      if (_currentIndex == 0)
        Consumer(
          builder: (context, ref, child) {
            final pendingCountAsync = ref.watch(pendingHandshakeCountProvider);
            return pendingCountAsync.when(
              data: (count) => Badge(
                label: Text(count.toString()),
                isLabelVisible: count > 0,
                alignment: Alignment.topRight,
                offset: const Offset(-4, 4),
                child: IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => context.push('/handshake-history'),
                  tooltip: 'Notifications',
                ),
              ),
              loading: () => IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => context.push('/handshake-history'),
              ),
              error: (_, __) => IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => context.push('/handshake-history'),
              ),
            );
          },
        ),
      if (_currentIndex == 1)
        isSearching
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  ref.read(contactsSearchModeProvider.notifier).state = false;
                  ref.read(contactsSearchQueryProvider.notifier).state = '';
                  _searchController.clear();
                },
              )
            : IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  ref.read(contactsSearchModeProvider.notifier).state = true;
                },
              ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Compact layout (phones, folded foldables) — original design preserved
  // ---------------------------------------------------------------------------

  Widget _buildCompactLayout(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final inactiveColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final docked = _useDockedDrawer(context);
    final pages = IndexedStack(index: _currentIndex, children: _pages);

    final scaffold = Scaffold(
      resizeToAvoidBottomInset: false,
      // When docked, the drawer is a permanent left column OUTSIDE this
      // Scaffold (see below), so the modal drawer is detached here.
      drawer: docked ? null : const AppDrawer(),
      appBar: _buildAppBar(context),
      body: pages,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SafeArea(
          bottom: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabTapped(0),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Icon(
                        _currentIndex == 0 ? Icons.share : Icons.share_outlined,
                        color:
                            _currentIndex == 0 ? primaryColor : inactiveColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 56),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabTapped(1),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Icon(
                        _currentIndex == 1
                            ? Icons.storage
                            : Icons.storage_outlined,
                        color:
                            _currentIndex == 1 ? primaryColor : inactiveColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onPrimaryAction(_currentIndex),
        backgroundColor: _currentIndex == 0 ? primaryColor : Colors.green,
        shape: const CircleBorder(),
        child: Icon(
          _currentIndex == 0 ? Icons.qr_code_scanner : Icons.camera_alt,
          size: 32,
          color: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );

    if (!docked) return scaffold;

    // Docked: the menu is a permanent left column spanning the FULL height
    // (from the very top), and the app bar / content / bottom bar all live in
    // the right-hand Scaffold. This keeps the "Share/Card" header attached to
    // the right content only, not pushing the menu down.
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            const SizedBox(
              width: 300,
              child: AppDrawer(isDocked: true),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: scaffold),
          ],
        ),
      ),
    );
  }
}
