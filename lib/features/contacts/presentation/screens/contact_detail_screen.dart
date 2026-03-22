import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/core/presentation/widgets/user_profile_avatar.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:secbizcard/features/contacts/data/services/vcard_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:secbizcard/core/utils/field_formatter.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  final UserProfile user;

  const ContactDetailScreen({super.key, required this.user});

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  late UserProfile _user;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      debugPrint('Could not launch $urlString');
    }
  }

  void _launchEmail(String email) {
    if (email.isEmpty) return;
    _launchUrl('mailto:$email');
  }

  void _launchPhone(String phone) {
    if (phone.isEmpty) return;
    _launchUrl('tel:$phone');
  }

  void _launchMap(String address) async {
    if (address.isEmpty) return;
    final encodedAddress = Uri.encodeComponent(address);
    // Try Google Maps URL first (works on both Android and iOS)
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
    final geoUrl = 'geo:0,0?q=$encodedAddress';

    // Try geo: URI first, fallback to Google Maps
    final geoUri = Uri.parse(geoUrl);
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      // Fallback to Google Maps web URL
      await launchUrl(
        Uri.parse(googleMapsUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  void _editContact() async {
    final updatedUser = await context.push('/edit-contact', extra: _user);
    if (updatedUser != null && updatedUser is UserProfile) {
      setState(() {
        _user = updatedUser;
      });
    }
  }

  void _exportToGoogle() async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    final String currentEmail = currentUser?.email ?? 'current account';

    // 1. Show choice dialog
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export to Google Contacts'),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'default'),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Use this account',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'switch'),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: const Row(
              children: [
                Icon(Icons.switch_account_outlined, color: Colors.grey),
                SizedBox(width: 12),
                Text('Or use another account'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    setState(() => _isExporting = true);

    final repo = ref.read(contactsRepositoryProvider);
    final result = await repo.saveToGoogleContacts(
      _user,
      forceAccountSelection: choice == 'switch',
    );

    if (!mounted) return;

    setState(() => _isExporting = false);

    result.fold(
      (l) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export Failed: ${l.message}'))),
      (r) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Exported successfully!'))),
    );
  }

  Future<void> _shareAsVCard() async {
    try {
      final vcardString = VCardService.generate(_user);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/${_user.displayName.replaceAll(' ', '_')}.vcf',
      );
      await file.writeAsString(vcardString);

      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Business Card: ${_user.displayName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share vCard: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = _user.customFields['Nickname'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editContact,
            tooltip: 'Edit Contact',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: UserProfileAvatar(
                photoUrl: _user.photoUrl,
                displayName: _user.displayName,
                radius: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _user.displayName,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            if (nickname != null && nickname.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '($nickname)',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],

            if (_user.title != null || _user.company != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  _user.title,
                  _user.company,
                ].where((e) => e != null && e.isNotEmpty).join(' • '),
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            if (_user.email != null && _user.email!.isNotEmpty)
              _buildContactTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _user.email!,
                onTap: () => _launchEmail(_user.email!),
                onLongPress: () => _copyToClipboard(_user.email!, 'Email'),
              ),

            if (_user.phone != null && _user.phone!.isNotEmpty)
              _buildContactTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _user.phone!,
                onTap: () => _launchPhone(_user.phone!),
                onLongPress: () => _copyToClipboard(_user.phone!, 'Phone'),
              ),

            if (_user.department != null && _user.department!.isNotEmpty)
              _buildContactTile(
                icon: Icons.business_center_outlined,
                label: 'Department',
                value: _user.department!,
              ),

            if (_user.address != null && _user.address!.isNotEmpty)
              _buildContactTile(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: _user.address!,
                onTap: () => _launchMap(_user.address!),
                onLongPress: () => _copyToClipboard(_user.address!, 'Address'),
              ),

            // Custom Fields
            if (_user.customFields.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              ..._user.customFields.entries
                  .where((e) => e.key != 'Nickname')
                  .map((entry) {
                    return _buildContactTile(
                      icon: FieldFormatter.getIcon(entry.key),
                      label: FieldFormatter.formatLabel(entry.key),
                      value: entry.value,
                      onTap: () {
                        if (entry.value.startsWith('http')) {
                          _launchUrl(entry.value);
                        } else {
                          _copyToClipboard(entry.value, entry.key);
                        }
                      },
                    );
                  }),
            ],

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isExporting ? null : _exportToGoogle,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.import_export),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Export to Google Contacts',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _shareAsVCard,
                icon: const Icon(Icons.share),
                label: const Text('Share as vCard (.vcf)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueGrey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.blueGrey[700]),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    );
  }

  // Removed duplicated _getIconForField and _formatFieldLabel as we use FieldFormatter

}
