import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:secbizcard/core/presentation/widgets/user_profile_avatar.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';

final contactsSearchQueryProvider = StateProvider<String>((ref) => '');
final contactsSearchModeProvider = StateProvider<bool>((ref) => false);

class ContactsListScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const ContactsListScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends ConsumerState<ContactsListScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Invalidation is now handled by the screens that actually modify contacts
    // (OCR, QR Scan, Handshake, etc.) to avoid redundant re-fetches.
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contactsAsync = ref.watch(savedContactsProvider);
    final searchQuery = ref.watch(contactsSearchQueryProvider);
    final isSearching = ref.watch(contactsSearchModeProvider);

    // Sync local controller if needed (though usually query is updated FROM controller)
    if (_searchController.text != searchQuery && !isSearching) {
      _searchController.text = searchQuery;
    }

    final content = contactsAsync.when(
      data: (rawContacts) {
        // 1. Filter
        final filtered = rawContacts.where((c) {
          if (searchQuery.isEmpty) return true;
          final q = searchQuery.toLowerCase();
          return c.displayName.toLowerCase().contains(q) ||
              (c.company?.toLowerCase().contains(q) ?? false) ||
              (c.title?.toLowerCase().contains(q) ?? false);
        }).toList();

        // 2. Sort (Alphabetical/Locale)
        // Standard compareTo handles basic Unicode sorting (en, zh, etc)
        filtered.sort((a, b) => a.displayName.compareTo(b.displayName));

        if (filtered.isEmpty) {
          if (searchQuery.isNotEmpty) {
            return Center(
              child: Text(
                'No contacts found for "$searchQuery"',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.contact_phone_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No contacts yet',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Exchanged or scanned cards will appear here',
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final contact = filtered[index];
            return Slidable(
              key: ValueKey(contact.uid),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.33,
                children: [
                  SlidableAction(
                    onPressed: (context) async {
                      final repo = ref.read(contactsRepositoryProvider);
                      final result = await repo.deleteContact(contact.uid);
                      result.fold(
                        (l) => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Delete failed: ${l.message}'),
                          ),
                        ),
                        (r) {
                          ref.invalidate(savedContactsProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contact deleted')),
                          );
                        },
                      );
                    },
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: 'Delete',
                  ),
                ],
              ),
              child: ListTile(
                leading: UserProfileAvatar(
                  photoUrl: contact.photoUrl,
                  displayName: contact.displayName,
                  radius: 24,
                ),
                title: Text(contact.displayName),
                subtitle: Text(
                  [
                    contact.title,
                    contact.company,
                  ].where((e) => e != null && e.isNotEmpty).join(' • '),
                ),
                onTap: () {
                  context.push('/contact-detail', extra: contact);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: isSearching
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
                'Card',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
        actions: [
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(contactsSearchModeProvider.notifier).state = false;
                ref.read(contactsSearchQueryProvider.notifier).state = '';
                _searchController.clear();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                ref.read(contactsSearchModeProvider.notifier).state = true;
              },
            ),
        ],
      ),
      body: content,
    );
  }
}
