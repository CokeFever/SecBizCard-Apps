import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/core/services/backup_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  bool _checkingBackup = true;
  bool _hasRemoteBackup = false;
  String? _statusMessage;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
    _checkRemoteBackup();
  }

  Future<void> _checkRemoteBackup() async {
    setState(() => _checkingBackup = true);
    final service = ref.read(backupServiceProvider);
    final hasBackup = await service.hasBackup();
    if (mounted) {
      setState(() {
        _hasRemoteBackup = hasBackup;
        _checkingBackup = false;
      });
    }
  }

  Future<void> _loadLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_backup_timestamp');
    if (timestamp != null) {
      if (mounted) {
        setState(() {
          _lastBackupTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        });
      }
    }
  }

  Future<void> _saveLastBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_backup_timestamp', time.millisecondsSinceEpoch);
    setState(() {
      _lastBackupTime = time;
    });
    // If we just backed up, we definitely have a backup now
    setState(() => _hasRemoteBackup = true);
  }

  Future<void> _performBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creating backup...';
    });

    final service = ref.read(backupServiceProvider);
    final result = await service.backup();

    if (!mounted) return;

    result.fold(
      (l) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Backup Failed: ${l.message}';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup Failed: ${l.message}')));
      },
      (time) {
        _saveLastBackupTime(time);
        setState(() {
          _isLoading = false;
          _statusMessage = 'Backup Successful!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup saved to Google Drive')),
        );
      },
    );
  }

  Future<void> _performRestore() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will overwrite your current contacts and settings. '
          'Make sure you have a recent backup. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Restoring from Drive...';
    });

    final service = ref.read(backupServiceProvider);
    final result = await service.restore();

    if (!mounted) return;

    result.fold(
      (l) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Restore Failed: ${l.message}';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore Failed: ${l.message}')));
      },
      (r) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Restore Completed!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Data restored successfully. Please restart app if needed.',
            ),
          ),
        );
        // Optionally navigate home or force refresh
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Backup & Restore',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        child: Column(
          children: [
            const Icon(
              Icons.cloud_sync_outlined,
              size: 80,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 24),
            Text(
              'Google Drive Backup',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Securely backup your contacts and settings to your Google Drive as an encrypted file.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
            const SizedBox(height: 48),

            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  if (_checkingBackup)
                    const LinearProgressIndicator(minHeight: 2),

                  if (_isLoading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_statusMessage ?? 'Processing...'),
                  ] else ...[
                    Text(
                      'Last Backup',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastBackupTime != null
                          ? DateFormat.yMMMd().add_jm().format(_lastBackupTime!)
                          : 'Never',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _statusMessage!.contains('Failed')
                              ? Colors.red
                              : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _performBackup,
                icon: const Icon(Icons.upload),
                label: const Text('Back Up Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading || _checkingBackup || !_hasRemoteBackup
                    ? null
                    : _performRestore,
                icon: const Icon(Icons.download),
                label: Text(
                  _checkingBackup
                      ? 'Checking...'
                      : (_hasRemoteBackup
                            ? 'Restore from Backup'
                            : 'No Backup Found'),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
