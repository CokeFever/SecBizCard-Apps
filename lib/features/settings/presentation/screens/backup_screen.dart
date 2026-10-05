import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/core/services/backup_service.dart';
import 'package:secbizcard/core/errors/failure.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/core/widgets/collapsible_section.dart';
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
  bool _checkingBackup = true;
  bool _hasRemoteBackup = false;
  String? _statusMessage;
  // Tracks whether the current status message is an error, so the UI can color
  // it red/green without inspecting the (now localized) message text.
  bool _statusIsError = false;
  DateTime? _lastBackupTime;
  bool _hasMagicWord = false;
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

    await result.fold(
      (l) async {
        // The cloud backup is locked with a magic word that isn't stored on
        // this device (new device / reinstall / after logout). Prompt for it,
        // store it, and retry — we only ask when the local value is absent.
        if (l is WrongMagicWordFailure) {
          final retried = await _promptMagicWordAndRetryRestore();
          if (retried) return;
        }
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupRestoreFailed(l.message);
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupRestoreFailed(l.message))),
        );
      },
      (r) async {
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

  /// Prompts for the backup's magic word (shown only when the local word is
  /// absent and the cloud file is magicword-locked), stores it, and retries the
  /// restore once. Returns true if the retry completed (success OR a handled
  /// wrong-word message), so the caller does not also show its generic error.
  Future<bool> _promptMagicWordAndRetryRestore() async {
    final l10n = AppLocalizations.of(context)!;
    final word = await _askForMagicWord();
    if (word == null) {
      // User cancelled — stop the spinner, leave a neutral status.
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
      return true;
    }

    // Store the entered word (normalized) so backup/restore use it from now on;
    // this is the "remember it on this device" behaviour. Length is validated
    // in the dialog, but guard anyway.
    try {
      await ref.read(magicWordServiceProvider).setMagicWord(word);
    } catch (_) {/* validated in dialog */}
    await _loadMagicWordState();

    final service = ref.read(backupServiceProvider);
    final result = await service.restore();
    if (!mounted) return true;

    result.fold(
      (l) {
        // Wrong word → clear it again so we prompt next time, and show a clear
        // wrong-word message rather than silently remembering a bad value.
        if (l is WrongMagicWordFailure) {
          ref.read(magicWordServiceProvider).clearMagicWord();
          _loadMagicWordState();
          setState(() {
            _isLoading = false;
            _statusMessage = l10n.magicWordRestoreWrong;
            _statusIsError = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.magicWordRestoreWrong)),
          );
          return;
        }
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.backupRestoreFailed(l.message);
          _statusIsError = true;
        });
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
      },
    );
    return true;
  }

  /// A single-field prompt for the magic word used during restore. Returns the
  /// normalized word, or null if cancelled. Enforces length 8-16.
  Future<String?> _askForMagicWord() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    bool obscure = true;
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
                Text(l10n.magicWordRestorePromptBody),
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
                      onPressed:
                          _isLoading || _checkingBackup || !_hasRemoteBackup
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
  /// confirm, runs the repack flow so the cloud backup is immediately re-locked
  /// with the new word.
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

  /// Runs the repack flow for a validated new magic word and reports the result.
  Future<void> _applyMagicWord(String word) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _statusMessage = l10n.magicWordSavedRepacking;
      _statusIsError = false;
    });

    final service = ref.read(backupServiceProvider);
    // D1: setting a magic word is now a pure LOCAL store — no Drive repack and
    // no backup. The new word takes effect on the next Back Up Now. (The full
    // UI/messaging redesign lands in FEAT-003; this call-site swap keeps the
    // screen compiling against the decoupled service signature.)
    final result = await service.setMagicWord(word);
    if (!mounted) return;

    await _loadMagicWordState();
    await _loadLastBackupTime();

    result.fold(
      (l) {
        final msg = l is MagicWordValidationFailure
            ? l10n.magicWordLengthError
            : l10n.magicWordRepackFailed(l.message);
        setState(() {
          _isLoading = false;
          _statusMessage = msg;
          _statusIsError = true;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      },
      (_) {
        setState(() {
          _isLoading = false;
          _statusMessage = l10n.magicWordSaved;
          _statusIsError = false;
          _hasRemoteBackup = true;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.magicWordSaved)));
      },
    );
  }
}
