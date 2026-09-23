import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/core/services/backup_service.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

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
  // Tracks whether the current status message is an error, so the UI can color
  // it red/green without inspecting the (now localized) message text.
  bool _statusIsError = false;
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

  Future<void> _performBackup({bool force = false}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _statusMessage = l10n.backupCreating;
      _statusIsError = false;
    });

    final service = ref.read(backupServiceProvider);
    final result = await service.backup(force: force);

    if (!mounted) return;

    await result.fold(
      (l) async {
        // A newer cloud backup exists (likely from another device). Don't
        // overwrite silently — warn the user and only force on confirmation.
        if (l is BackupConflictFailure) {
          setState(() {
            _isLoading = false;
            _statusMessage = l10n.backupCloudNewerStatus;
            _statusIsError = true;
          });
          final overwrite = await _confirmOverwriteNewerBackup(l);
          if (overwrite == true) {
            await _performBackup(force: true);
          }
          return;
        }
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupFailed(l.message);
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupFailed(l.message))),
        );
      },
      (time) async {
        _saveLastBackupTime(time);
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupSuccessStatus;
          _statusIsError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupSavedToDrive)),
        );
      },
    );
  }

  /// Warns that the Google Drive backup is newer than this device before
  /// letting the user overwrite it. Returns true if they choose to overwrite.
  Future<bool?> _confirmOverwriteNewerBackup(BackupConflictFailure conflict) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final cloudLocal = conflict.cloudModifiedTime.toLocal();
    final localStr = conflict.localModifiedTime == null
        ? l10n.backupNeverChangedOnDevice
        : l10n.backupLastChanged(fmt.format(conflict.localModifiedTime!.toLocal()));
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupCloudNewerTitle),
        content: Text(
          l10n.backupCloudNewerBody(fmt.format(cloudLocal), localStr),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.backupOverwrite),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore() async {
    final l10n = AppLocalizations.of(context)!;
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreConfirmTitle),
        content: Text(l10n.backupRestoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.backupRestoreAction),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = l10n.backupRestoringStatus;
      _statusIsError = false;
    });

    final service = ref.read(backupServiceProvider);
    final result = await service.restore();

    if (!mounted) return;

    result.fold(
      (l) {
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupRestoreFailed(l.message);
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupRestoreFailed(l.message))),
        );
      },
      (r) {
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupRestoreCompletedStatus;
          _statusIsError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupRestoreSuccessBody)),
        );
        // Optionally navigate home or force refresh
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.drawerBackupRestore,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: Breakpoints.maxContentWidth,
            minHeight: double.infinity,
          ),
          child: Container(
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
              l10n.backupDriveTitle,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.backupDriveDesc,
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
                    Text(_statusMessage ?? l10n.backupProcessing),
                  ] else ...[
                    Text(
                      l10n.backupLastBackupLabel,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _lastBackupTime != null
                          ? DateFormat.yMMMd().add_jm().format(_lastBackupTime!)
                          : l10n.backupNever,
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
                          color: _statusIsError ? Colors.red : Colors.green,
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
                label: Text(l10n.backupNowButton),
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
                      ? l10n.backupChecking
                      : (_hasRemoteBackup
                            ? l10n.backupRestoreFromBackup
                            : l10n.backupNoBackupFound),
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
        ),
      ),
    );
  }
}
