import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:secbizcard/core/presentation/widgets/user_profile_avatar.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';

import 'package:secbizcard/features/profile/domain/user_profile.dart';

final contactsSearchQueryProvider = StateProvider<String>((ref) => '');
final contactsSearchModeProvider = StateProvider<bool>((ref) => false);

/// The contacts actually shown in the list: raw saved contacts filtered by the
/// current search query and sorted alphabetically. Both the list AND the
/// select-all action consume this, so "select all" always matches exactly what
/// the user sees (no raw-vs-filtered mismatch).
final filteredContactsProvider = Provider<List<UserProfile>>((ref) {
  final raw = ref.watch(savedContactsProvider).valueOrNull ?? const [];
  final query = ref.watch(contactsSearchQueryProvider).toLowerCase();
  final filtered = raw.where((c) {
    if (query.isEmpty) return true;
    return c.displayName.toLowerCase().contains(query) ||
        (c.company?.toLowerCase().contains(query) ?? false) ||
        (c.title?.toLowerCase().contains(query) ?? false);
  }).toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));
  return filtered;
});

/// Multi-select state for the contacts list. Mirrors the search-mode pattern:
/// shared providers so the embedded list AND the parent MainScreen AppBar stay
/// in sync (the list toggles selection; the AppBar shows count + batch actions).
final contactsSelectionModeProvider = StateProvider<bool>((ref) => false);
final contactsSelectedIdsProvider = StateProvider<Set<String>>((ref) => {});

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

  /// Toggle a contact's membership in the current selection. Leaving the last
  /// item deselected exits selection mode (matches the platform convention).
  void _toggleSelection(String uid) {
    final current = ref.read(contactsSelectedIdsProvider);
    final next = Set<String>.from(current);
    if (next.contains(uid)) {
      next.remove(uid);
    } else {
      next.add(uid);
    }
    ref.read(contactsSelectedIdsProvider.notifier).state = next;
    if (next.isEmpty) {
      ref.read(contactsSelectionModeProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(savedContactsProvider);
    final searchQuery = ref.watch(contactsSearchQueryProvider);
    final isSearching = ref.watch(contactsSearchModeProvider);

    // Sync local controller if needed (though usually query is updated FROM controller)
    if (_searchController.text != searchQuery && !isSearching) {
      _searchController.text = searchQuery;
    }

    final content = contactsAsync.when(
      data: (rawContacts) {
        // Single source of truth for the visible list (filter + sort) — shared
        // with the select-all action via filteredContactsProvider.
        final filtered = ref.watch(filteredContactsProvider);

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

        final selectionMode = ref.watch(contactsSelectionModeProvider);
        final selectedIds = ref.watch(contactsSelectedIdsProvider);

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final contact = filtered[index];
            final isSelected = selectedIds.contains(contact.uid);

            final tile = ListTile(
              selected: isSelected,
              selectedTileColor:
                  theme.colorScheme.primary.withValues(alpha: 0.08),
              leading: selectionMode
                  ? _SelectionAvatar(
                      isSelected: isSelected,
                      contact: contact,
                    )
                  : UserProfileAvatar(
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
                if (selectionMode) {
                  _toggleSelection(contact.uid);
                } else {
                  context.push('/contact-detail', extra: contact);
                }
              },
              onLongPress: () {
                // Long-press enters multi-select and picks this contact.
                if (!selectionMode) {
                  ref.read(contactsSelectionModeProvider.notifier).state = true;
                }
                _toggleSelection(contact.uid);
              },
            );

            // Swipe-to-delete is the ONLY delete entry point, and it's disabled
            // while selecting (delete is deliberately kept single-item, never
            // batch — see the design decision).
            if (selectionMode) return tile;

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
              child: tile,
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
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.inter(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
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

/// Leading widget shown while in multi-select mode: a filled check when
/// selected, otherwise the normal avatar (so the row still reads as a contact).
class _SelectionAvatar extends StatelessWidget {
  const _SelectionAvatar({required this.isSelected, required this.contact});

  final bool isSelected;
  final dynamic contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isSelected) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.check, color: Colors.white),
      );
    }
    return UserProfileAvatar(
      photoUrl: contact.photoUrl,
      displayName: contact.displayName,
      radius: 24,
    );
  }
}
