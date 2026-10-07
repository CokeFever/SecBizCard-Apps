import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/core/services/backup_service.dart';
import 'package:secbizcard/core/services/backup_phase.dart';
import 'package:secbizcard/core/services/backup_reminder_service.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/core/widgets/collapsible_section.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/settings/data/magic_word_service.dart';
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
  // A1: hard re-entrancy guard that covers the ENTIRE operation, including the
  // async pre-flight (confirm dialogs, cloud checks) that runs BEFORE
  // _isLoading flips true. A second tap during that window returns immediately
  // so it can never start a concurrent backup/restore. Set/cleared in a
  // try/finally so it is released on BOTH success and failure.
  bool _opInProgress = false;
  bool _checkingBackup = true;
  bool _hasRemoteBackup = false;
  String? _statusMessage;
  // Tracks whether the current status message is an error, so the UI can color
  // it red/green without inspecting the (now localized) message text.
  bool _statusIsError = false;
  DateTime? _lastBackupTime;
  bool _hasMagicWord = false;
  // D8/D13: whether there is any local contact. Back Up Now is gated on this so
  // an empty local state can never overwrite the cloud; the gate is contacts-
  // only per D13. Loaded in initState and refreshed after a successful restore.
  bool _hasLocalContacts = false;
  // Inline reveal state for the stored magic word (Issue 2): the word is shown
  // masked by default inside the section; the eye toggle reveals/hides it in
  // place rather than opening a popup. Loaded lazily when the user first taps
  // the eye so the secure value isn't held in memory longer than needed.
  bool _magicWordRevealed = false;
  String? _revealedMagicWord;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
    _checkRemoteBackup();
    _loadMagicWordState();
    _loadLocalDataState();
  }

  /// D8/D13: loads whether the device has any local contact. Contacts-only
  /// gate — an empty contacts list disables Back Up Now and steers the user to
  /// Restore. Refreshed after a successful restore.
  Future<void> _loadLocalDataState() async {
    final result = await ref.read(contactsRepositoryProvider).getSavedContacts();
    final hasContacts = result.fold((_) => false, (list) => list.isNotEmpty);
    if (mounted) {
      setState(() => _hasLocalContacts = hasContacts);
    }
  }

  Future<void> _loadMagicWordState() async {
    final has = await ref.read(magicWordServiceProvider).hasMagicWord();
    if (mounted) {
      setState(() {
        _hasMagicWord = has;
        // Re-hide and drop any cached plaintext whenever the word state changes
        // (set/change/clear) so a stale value is never shown.
        _magicWordRevealed = false;
        _revealedMagicWord = null;
      });
    }
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

  /// A2: maps a backup phase to its localized "Preparing… / Encrypting… /
  /// Uploading…" (and restore equivalents) status text.
  String _backupPhaseLabel(BackupPhase phase, AppLocalizations l10n) {
    switch (phase) {
      case BackupPhase.preparing:
        return l10n.backupPhasePreparing;
      case BackupPhase.encrypting:
        return l10n.backupPhaseEncrypting;
      case BackupPhase.uploading:
        return l10n.backupPhaseUploading;
      case BackupPhase.downloading:
        return l10n.restorePhaseDownloading;
      case BackupPhase.decrypting:
        return l10n.restorePhaseDecrypting;
      case BackupPhase.restoring:
        return l10n.restorePhaseRestoring;
    }
  }

  /// C (backup): selects a friendly, localized message by failure TYPE so the
  /// user NEVER sees raw ClientException/PlatformException text. Returns null
  /// for failures that already have their own dedicated UI handling
  /// (conflict/empty/magic-word), so the caller can keep that behavior.
  String? _backupErrorMessage(Failure l, AppLocalizations l10n) {
    if (l is ConnectionFailure) return l10n.backupErrorOffline;
    if (l is InterruptedTransferFailure) return l10n.backupErrorInterrupted;
    if (l is AuthFailure) return l10n.backupErrorAuth;
    if (l is EmptyBackupFailure) return l10n.backupErrorGeneric;
    if (l is BackupConflictFailure) return null; // handled by caller
    return l10n.backupErrorGeneric;
  }

  /// C (restore): friendly, localized message by failure TYPE for restore.
  /// Returns null for WrongMagicWordFailure (the caller runs its own retry
  /// prompt).
  String? _restoreErrorMessage(Failure l, AppLocalizations l10n) {
    if (l is WrongMagicWordFailure) return null; // handled by caller
    if (l is ConnectionFailure) return l10n.restoreErrorOffline;
    if (l is InterruptedTransferFailure) return l10n.restoreErrorInterrupted;
    if (l is AuthFailure) return l10n.restoreErrorAuth;
    return l10n.restoreErrorGeneric;
  }

  /// A1: the ONLY public entry for a backup. Sets the re-entrancy guard and
  /// shows immediate "Preparing…" feedback at the VERY FIRST line — before any
  /// cloud check or confirm dialog — so a tap never feels dead, and a second
  /// tap during the pre-flight is ignored. The guard/spinner are released in a
  /// finally so they clear on BOTH success and failure. A conflict→overwrite
  /// retry runs inside this same guarded session via [_runBackup].
  Future<void> _performBackup() async {
    if (_opInProgress) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _opInProgress = true;
      _isLoading = true;
      _statusMessage = l10n.backupPhasePreparing;
      _statusIsError = false;
    });
    try {
      await _runBackup(force: false);
    } finally {
      if (mounted) {
        setState(() {
          _opInProgress = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Runs one backup attempt. Assumes the caller ([_performBackup]) already set
  /// the re-entrancy guard and immediate feedback; this never touches
  /// `_opInProgress`. On a newer-cloud conflict it asks to overwrite and, on
  /// confirmation, retries once with `force: true` INSIDE the same guarded
  /// session (no second public entry, so no concurrent op can slip in).
  Future<void> _runBackup({required bool force}) async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(backupServiceProvider);

    // D11: warn before silently stripping magic-word protection. When the cloud
    // file is magicword-protected but this device has no magic word, a backup
    // would re-encrypt the cloud with the default (uid) mode and drop the lock.
    // Confirm first; abort if the user cancels. Only on the first (non-force)
    // attempt — a forced retry has already been confirmed.
    if (!force) {
      final cloudProtected = await service.cloudIsMagicWordProtected();
      if (!mounted) return;
      if (cloudProtected) {
        final hasLocalWord =
            await ref.read(magicWordServiceProvider).hasMagicWord();
        if (!mounted) return;
        if (!hasLocalWord) {
          final proceed = await _confirmDowngrade();
          if (proceed != true) return;
        }
      }
    }

    // Keep the staged "Preparing…" already shown by _performBackup; the phase
    // callback below advances it to Encrypting… / Uploading… wired to the real
    // work in BackupService.
    final result = await service.backup(
      force: force,
      onPhase: (phase) {
        if (!mounted) return;
        setState(() {
          _statusMessage = _backupPhaseLabel(phase, l10n);
          _statusIsError = false;
        });
      },
    );

    if (!mounted) return;

    await result.fold(
      (l) async {
        // A newer cloud backup exists (likely from another device). Don't
        // overwrite silently — warn the user and only force on confirmation.
        if (l is BackupConflictFailure) {
          setState(() {
            _statusMessage = l10n.backupCloudNewerStatus;
            _statusIsError = true;
          });
          final overwrite = await _confirmOverwriteNewerBackup(l);
          if (overwrite == true) {
            await _runBackup(force: true);
          }
          return;
        }
        // C: friendly, localized message by failure TYPE — never the raw
        // ClientException/PlatformException text.
        final msg = _backupErrorMessage(l, l10n) ?? l10n.backupErrorGeneric;
        setState(() {
          _statusMessage = msg;
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
      (time) async {
        _saveLastBackupTime(time);
        setState(() {
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

  /// D11: confirms before a backup removes magic-word protection from the cloud
  /// file. Returns true if the user chooses to continue.
  Future<bool?> _confirmDowngrade() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupDowngradeTitle),
        content: Text(l10n.backupDowngradeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
  }

  /// A1: the ONLY public entry for a restore. The re-entrancy guard is set at
  /// the VERY FIRST line so a double-tap can never open two confirm dialogs or
  /// start two restores; it is released in a finally on BOTH success and
  /// failure. The confirm dialog itself is the immediate feedback for the first
  /// tap; the "Downloading…/Decrypting…/Restoring…" spinner appears once the
  /// user confirms and the real work starts.
  Future<void> _performRestore() async {
    if (_opInProgress) return;
    _opInProgress = true;
    try {
      await _runRestore();
    } finally {
      if (mounted) {
        setState(() {
          _opInProgress = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runRestore() async {
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

    final service = ref.read(backupServiceProvider);

    // D12: reverse-staleness warning. If the cloud backup is OLDER than this
    // device's latest local change, restoring would overwrite newer local data
    // with an older backup. Warn and require a second confirmation.
    final cloudTime = await service.cloudBackupModifiedTime();
    final localTime = await BackupReminderService().lastModifiedAt();
    if (!mounted) return;
    if (cloudTime != null &&
        localTime != null &&
        cloudTime.isBefore(localTime)) {
      final proceed = await _confirmStaleRestore(cloudTime, localTime);
      if (proceed != true) return;
    }

    // D4a: capture whether a local magic word was present before the restore so
    // the retry prompt (on WrongMagicWordFailure) can choose the no-word vs
    // wrong-word body.
    final hadLocalWord =
        await ref.read(magicWordServiceProvider).hasMagicWord();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = l10n.restorePhaseDownloading;
      _statusIsError = false;
    });

    final result = await service.restore(
      onPhase: (phase) {
        if (!mounted) return;
        setState(() {
          _statusMessage = _backupPhaseLabel(phase, l10n);
          _statusIsError = false;
        });
      },
    );

    if (!mounted) return;

    await result.fold(
      (l) async {
        // The cloud backup is locked with a magic word that can't be unlocked
        // with the value stored on this device (new device / reinstall / after
        // logout, or a stale/wrong stored word). Prompt for it and retry; the
        // entered word is used for that decrypt only and stored only if the
        // user later chooses to remember it.
        if (l is WrongMagicWordFailure) {
          final retried = await _promptMagicWordAndRetryRestore(hadLocalWord);
          if (retried) return;
        }
        if (!mounted) return;
        // C: friendly, localized message by failure TYPE — never raw
        // ClientException/PlatformException text.
        final msg = _restoreErrorMessage(l, l10n) ?? l10n.restoreErrorGeneric;
        setState(() {
          _statusMessage = msg;
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
      (r) async {
        // Restore wrote local data — refresh the contacts gate so Back Up Now
        // becomes available again.
        await _loadLocalDataState();
        if (!mounted) return;
        setState(() {
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

  /// D12: confirms before restoring a cloud backup that is older than the
  /// latest local change. Returns true if the user chooses to continue.
  Future<bool?> _confirmStaleRestore(DateTime cloudTime, DateTime localTime) {
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreStaleTitle),
        content: Text(
          l10n.backupRestoreStaleBody(
            fmt.format(cloudTime.toLocal()),
            fmt.format(localTime.toLocal()),
          ),
        ),
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
  }

  /// Prompts for the backup's magic word and retries the restore once using the
  /// entered word for THAT decrypt only (D4b — no auto-store). [hadLocalWord]
  /// selects the prompt body (D4a): a stored-but-wrong word vs no stored word.
  /// On success, asks whether to remember the word on this device and only then
  /// stores it. Returns true if the retry completed (success OR a handled
  /// wrong-word message), so the caller does not also show its generic error.
  Future<bool> _promptMagicWordAndRetryRestore(bool hadLocalWord) async {
    final l10n = AppLocalizations.of(context)!;
    final word = await _askForMagicWord(hadLocalWord);
    if (word == null) {
      // User cancelled — leave a neutral status; the spinner is cleared by the
      // finally in _performRestore when the guarded session unwinds.
      setState(() {
        _statusMessage = null;
      });
      return true;
    }

    // D4b: use the entered word for this decrypt ONLY — do NOT persist it before
    // the retry. restore(overrideMagicWord:) decrypts with the override without
    // storing it.
    final service = ref.read(backupServiceProvider);
    final result = await service.restore(
      overrideMagicWord: word,
      onPhase: (phase) {
        if (!mounted) return;
        setState(() {
          _statusMessage = _backupPhaseLabel(phase, l10n);
          _statusIsError = false;
        });
      },
    );
    if (!mounted) return true;

    await result.fold(
      (l) async {
        // Wrong word again — show a clear message and store nothing.
        if (l is WrongMagicWordFailure) {
          setState(() {
            _statusMessage = l10n.magicWordRestoreWrong;
            _statusIsError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.magicWordRestoreWrong)),
          );
          return;
        }
        // C: friendly, localized message by failure TYPE.
        final msg = _restoreErrorMessage(l, l10n) ?? l10n.restoreErrorGeneric;
        setState(() {
          _statusMessage = msg;
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
      (r) async {
        // Restore succeeded with the entered word. Refresh the contacts gate,
        // then ask whether to remember the word on this device (D4b) — only on
        // "Remember" do we persist it.
        await _loadLocalDataState();
        if (!mounted) return;
        setState(() {
          _statusMessage = l10n.backupRestoreCompletedStatus;
          _statusIsError = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupRestoreSuccessBody)),
        );
        final remember = await _askRememberMagicWord();
        if (remember == true) {
          await ref.read(magicWordServiceProvider).setMagicWord(word);
          await _loadMagicWordState();
        }
      },
    );
    return true;
  }

  /// D4b: after a successful override-restore, asks whether to store the entered
  /// magic word on this device so future backups/restores use it automatically.
  Future<bool?> _askRememberMagicWord() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.magicWordRememberTitle),
        content: Text(l10n.magicWordRememberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.magicWordRememberNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.magicWordRememberYes),
          ),
        ],
      ),
    );
  }

  /// A single-field prompt for the magic word used during restore. Returns the
  /// normalized word, or null if cancelled. Enforces length 8-16. [hadLocalWord]
  /// selects the body (D4a): a stored word that cannot decrypt vs no stored word.
  Future<String?> _askForMagicWord(bool hadLocalWord) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    bool obscure = true;
    final promptBody = hadLocalWord
        ? l10n.magicWordRestorePromptBodyWrongWord
        : l10n.magicWordRestorePromptBodyNoWord;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final value = controller.text;
          final valid = MagicWordService.isValid(value);
          return AlertDialog(
            title: Text(l10n.magicWordRestorePromptTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promptBody),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.magicWordEnterLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setLocal(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(
                        context, MagicWordService.normalize(value))
                    : null,
                child: Text(l10n.commonContinue),
              ),
            ],
          );
        },
      ),
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
      // SafeArea(bottom) + a plain scrollable column (Task 2). Content scrolls
      // naturally and the two bottom buttons sit at the end of the document
      // with normal spacing — no Spacer()/IntrinsicHeight compression — while
      // the bottom padding adds the system inset so they clear the Android nav
      // bar.
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.cloud_sync_outlined,
                    size: 80,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.backupDriveTitle,
                    textAlign: TextAlign.center,
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
                  const SizedBox(height: 24),

                  // Last Backup status card (always visible).
                  SectionCard(
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _lastBackupTime != null
                                ? DateFormat.yMMMd()
                                    .add_jm()
                                    .format(_lastBackupTime!)
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
                                color: _statusIsError
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

                  const SizedBox(height: 24),
                  // Magic Word section (always visible).
                  _buildMagicWordSection(l10n),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      // D8/D13: disabled while loading or when there are no local
                      // contacts — an empty local state must never overwrite the
                      // cloud. Set/Change Magic Word stays enabled (it no longer
                      // backs up).
                      onPressed: _isLoading || _opInProgress || !_hasLocalContacts
                          ? null
                          : _performBackup,
                      icon: const Icon(Icons.upload),
                      label: Text(l10n.backupNowButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  // D8/D13 steer hints: explain why Back Up Now is disabled and,
                  // when a cloud backup exists, point the user to Restore first.
                  if (!_isLoading && !_hasLocalContacts) ...[
                    const SizedBox(height: 8),
                    Text(
                      _hasRemoteBackup
                          ? l10n.backupRestoreFirstHint
                          : l10n.backupEmptyDisabledHint,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ||
                              _opInProgress ||
                              _checkingBackup ||
                              !_hasRemoteBackup
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The "set / change magic word" section. Explains the privacy benefit and
  /// the irreversibility risk, offers set/change, and (when a word is set) a
  /// reveal + copy so the owner can send it to a secretary.
  Widget _buildMagicWordSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_hasMagicWord ? Icons.lock : Icons.lock_open,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.magicWordSectionTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasMagicWord
                ? l10n.magicWordSectionDescSet
                : l10n.magicWordSectionDescNone,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _openSetMagicWordDialog,
                icon: Icon(_hasMagicWord ? Icons.edit : Icons.key, size: 18),
                label: Text(_hasMagicWord
                    ? l10n.magicWordChangeButton
                    : l10n.magicWordSetButton),
              ),
            ],
          ),
          if (_hasMagicWord) ...[
            const SizedBox(height: 12),
            _buildStoredMagicWordField(l10n, theme),
          ],
        ],
      ),
    );
  }

  /// Inline, read-only display of the stored magic word (Issue 2). Masked by
  /// default (standard password-field pattern): the eye toggle reveals/hides it
  /// in place and the copy button sends it to the clipboard so the owner can
  /// resend it (e.g. to a secretary). Replaces the former plaintext popup.
  Widget _buildStoredMagicWordField(AppLocalizations l10n, ThemeData theme) {
    final revealed = _magicWordRevealed && _revealedMagicWord != null;
    final display = revealed
        ? _revealedMagicWord!
        : '\u2022' * 8; // dots as a fixed-width mask, never the real length
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.magicWordStoredLabel,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip:
                      revealed ? l10n.magicWordHide : l10n.magicWordReveal,
                  icon: Icon(
                    revealed ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: _isLoading ? null : _toggleRevealMagicWord,
                ),
                IconButton(
                  tooltip: l10n.magicWordCopy,
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: _isLoading ? null : _copyStoredMagicWord,
                ),
              ],
            ),
          ),
          child: Text(
            display,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Toggles the inline reveal. On reveal it lazily reads the stored word; on
  /// hide it drops the cached plaintext.
  Future<void> _toggleRevealMagicWord() async {
    if (_magicWordRevealed) {
      setState(() {
        _magicWordRevealed = false;
        _revealedMagicWord = null;
      });
      return;
    }
    final word = await ref.read(magicWordServiceProvider).getMagicWord();
    if (!mounted || word == null) return;
    setState(() {
      _revealedMagicWord = word;
      _magicWordRevealed = true;
    });
  }

  /// Copies the stored magic word to the clipboard (reads it fresh so copy
  /// works whether or not it is currently revealed).
  Future<void> _copyStoredMagicWord() async {
    final l10n = AppLocalizations.of(context)!;
    final word = await ref.read(magicWordServiceProvider).getMagicWord();
    if (!mounted || word == null) return;
    await Clipboard.setData(ClipboardData(text: word));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.magicWordCopied)),
    );
  }

  /// Set/change dialog: a SINGLE entry field (Issue 3 — the magic word is
  /// viewable in-app, so a typo is self-correctable; no second confirm field),
  /// reveal toggle, copy, a strong irreversibility warning, length 8-16. On
  /// confirm, stores the word LOCALLY only (D1) — no Drive op and no backup; the
  /// new word takes effect on the next Back Up Now.
  Future<void> _openSetMagicWordDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final wordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final word = wordController.text;
          final normalized = MagicWordService.normalize(word);
          final lengthOk = MagicWordService.isValid(word);
          final errorText =
              (word.isNotEmpty && !lengthOk) ? l10n.magicWordLengthError : null;
          final canConfirm = lengthOk;

          return AlertDialog(
            title: Text(l10n.magicWordDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: wordController,
                    autofocus: true,
                    obscureText: obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      labelText: l10n.magicWordEnterLabel,
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      suffixIcon: IconButton(
                        icon: Icon(obscure
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setLocal(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.magicWordRule,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (normalized.isNotEmpty)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: normalized));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.magicWordCopied)),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(l10n.magicWordCopy),
                        ),
                      ],
                    ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.magicWordForgetWarning,
                            style: const TextStyle(
                                fontSize: 12, height: 1.4, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.pop(context, normalized)
                    : null,
                child: Text(l10n.commonContinue),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == null || !mounted) return;
    await _applyMagicWord(confirmed);
  }

  /// D1: stores a validated new magic word LOCALLY only — no Drive op and no
  /// backup. On success it shows a persistent "takes effect on your next
  /// backup" status and leaves the backup state (_hasRemoteBackup /
  /// _lastBackupTime) untouched; the word applies on the next Back Up Now.
  Future<void> _applyMagicWord(String word) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _statusMessage = l10n.backupProcessing;
      _statusIsError = false;
    });

    final service = ref.read(backupServiceProvider);
    final result = await service.setMagicWord(word);
    if (!mounted) return;

    await _loadMagicWordState();

    result.fold(
      (l) {
        final msg = l is MagicWordValidationFailure
            ? l10n.magicWordLengthError
            : l10n.commonErrorWithDetail(l.message);
        setState(() {
          _isLoading = false;
          _statusMessage = msg;
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      },
      (_) {
        // D1: pure local store — no backup. Persistent status tells the user the
        // word applies on the next backup. Do NOT touch _hasRemoteBackup or
        // _lastBackupTime.
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupSetWordNextBackupHint;
          _statusIsError = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.magicWordSaved)));
      },
    );
  }
}
