import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/core/widgets/app_drawer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/handshake/presentation/screens/qr_display_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/contacts_list_screen.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/handshake/data/handshake_history_repository.dart';

class MainScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MainScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late int _currentIndex;
  bool _isProcessingTap = false;

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

    // If switching AWAY from contacts, stop searching
    if (index != 1) {
      ref.read(contactsSearchModeProvider.notifier).state = false;
      ref.read(contactsSearchQueryProvider.notifier).state = '';
      _searchController.clear();
    } else {
      // Switching TO contacts - refresh the list
      ref.invalidate(savedContactsProvider);
    }

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _isProcessingTap = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSearching = ref.watch(contactsSearchModeProvider);

    final inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: (_currentIndex == 1 && isSearching)
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.inter(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Search by name, company...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (v) =>
                    ref.read(contactsSearchQueryProvider.notifier).state = v,
              )
            : Text(
                _currentIndex == 0 ? 'Share' : 'Card',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
        actions: [
          if (_currentIndex == 0)
            Consumer(
              builder: (context, ref, child) {
                final pendingCountAsync = ref.watch(pendingHandshakeCountProvider);
                return pendingCountAsync.when(
                  data: (count) => Badge(
                    label: Text(count.toString()),
                    isLabelVisible: count > 0,
                    alignment: Alignment.topRight,
                    offset: const Offset(-4, 4), // Move slightly towards bottom-left
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () {
                        context.push('/handshake-history');
                      },
                      tooltip: 'Notifications',
                    ),
                  ),
                  loading: () => IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {
                      context.push('/handshake-history');
                    },
                  ),
                  error: (_, __) => IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () {
                      context.push('/handshake-history');
                    },
                  ),
                );
              },
            ),
          if (_currentIndex == 1)
            isSearching
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(contactsSearchModeProvider.notifier).state =
                          false;
                      ref.read(contactsSearchQueryProvider.notifier).state = '';
                      _searchController.clear();
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      ref.read(contactsSearchModeProvider.notifier).state =
                          true;
                    },
                  ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
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
                      color: _currentIndex == 0 ? primaryColor : inactiveColor,
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
                      color: _currentIndex == 1 ? primaryColor : inactiveColor,
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
        onPressed: () {
          if (_currentIndex == 0) {
            context.push('/qr-scanner');
          } else {
            context.push('/scan');
          }
        },
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
  }
}
