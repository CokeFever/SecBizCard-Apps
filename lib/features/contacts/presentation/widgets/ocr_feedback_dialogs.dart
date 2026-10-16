import 'package:flutter/material.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'package:secbizcard/features/contacts/data/ocr_feedback_service.dart';

/// UI for the "report bad recognition" flow (see docs/ocr_feedback_design.md).
///
/// Two steps, both opt-in and shown only when appropriate:
///  1. [maybePromptOnLeave] — the Back-press prompt asking whether recognition
///     was poor, with a "don't ask for 24h" checkbox. Only call this when the
///     predictor flagged the result as likely-poor AND the prompt isn't
///     suppressed.
///  2. [collectFeedbackIfAny] — the consent dialog (concise summary + expandable
///     full terms + optional include-photo). It only COLLECTS consent and
///     returns an [OcrFeedbackSubmission] (or null); it performs NO upload and
///     shows NO toast. The actual submit runs detached, after the screen pops,
///     so backing out of the review screen never cancels an in-flight upload.
///
/// Consent legal text is a PLACEHOLDER pending legal review (see the arb key
/// `ocrFeedbackTermsBody`).
class OcrFeedbackDialogs {
  /// Shows the Back-press prompt. Returns true if the user chose to proceed to
  /// reporting. Handles the "don't ask for 24h" suppression internally.
  static Future<bool> maybePromptOnLeave(
    BuildContext context,
    OcrFeedbackService service,
  ) async {
    if (await service.isPromptSuppressed()) return false;
    if (!context.mounted) return false;

    final l10n = AppLocalizations.of(context)!;
    bool dontAsk = false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.ocrFeedbackPromptTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.ocrFeedbackPromptBody),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: dontAsk,
                onChanged: (v) => setState(() => dontAsk = v ?? false),
                title: Text(l10n.ocrFeedbackDontAsk24h),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.ocrFeedbackDismiss),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.ocrFeedbackReport),
            ),
          ],
        ),
      ),
    );

    if (dontAsk) {
      await service.suppressPromptFor24h();
    }
    return proceed ?? false;
  }

  /// Runs the Back-press prompt + consent dialog on [context] and, on
  /// agreement, returns an immutable [OcrFeedbackSubmission] (sample + the
  /// include-photo choice). Returns null if the user declined/cancelled at any
  /// dialog. Performs NO upload and shows NO toast — the caller submits the
  /// returned struct detached (after popping the screen) so the upload outlives
  /// the review screen's lifecycle.
  static Future<OcrFeedbackSubmission?> collectFeedbackIfAny(
    BuildContext context,
    OcrFeedbackService service,
    OcrFeedbackSample sample,
  ) async {
    final proceed = await maybePromptOnLeave(context, service);
    if (!proceed || !context.mounted) return null;

    final l10n = AppLocalizations.of(context)!;
    // Photo is included by DEFAULT (opt-out): the card image is what makes the
    // feedback useful for fixing recognition. It stays a checkbox the user can
    // untick, so consent remains specific and revocable (never bundled) — which
    // is what the consent copy promises ("always optional, asked each time").
    bool includePhoto = true;
    bool showTerms = false;

    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.ocrFeedbackConsentTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.ocrFeedbackConsentSummary),
                if (sample.imagePath != null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    value: includePhoto,
                    onChanged: (v) =>
                        setState(() => includePhoto = v ?? false),
                    title: Text(l10n.ocrFeedbackConsentIncludePhoto),
                  ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => setState(() => showTerms = !showTerms),
                  child: Row(
                    children: [
                      Icon(showTerms
                          ? Icons.expand_less
                          : Icons.expand_more),
                      const SizedBox(width: 4),
                      Text(l10n.ocrFeedbackViewTerms),
                    ],
                  ),
                ),
                if (showTerms)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.ocrFeedbackTermsBody,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.ocrFeedbackCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.ocrFeedbackSubmit),
            ),
          ],
        ),
      ),
    );

    if (agreed != true) return null;

    // No upload here: hand the collected consent back to the caller, which
    // submits it detached after popping. The include-photo derivation must
    // stay identical to the (previous) showConsentAndSubmit so opt-out-photo is
    // preserved: the service receives imagePath only when the box is ticked.
    return OcrFeedbackSubmission(sample: sample, includePhoto: includePhoto);
  }
}

/// Immutable result of [OcrFeedbackDialogs.collectFeedbackIfAny]: the gathered
/// sample plus the user's include-photo choice. Holds no widget/context so the
/// detached submit that consumes it can outlive the review screen.
class OcrFeedbackSubmission {
  const OcrFeedbackSubmission({
    required this.sample,
    required this.includePhoto,
  });

  final OcrFeedbackSample sample;
  final bool includePhoto;
}

/// Everything needed to submit a feedback sample, gathered by the caller.
class OcrFeedbackSample {
  const OcrFeedbackSample({
    required this.engine,
    this.recognitionId,
    this.appVersion,
    this.ocrPkgVersion,
    this.cardLanguage,
    this.region,
    required this.rawOcrLines,
    this.parsedResult,
    this.confidence,
    this.imagePath,
  });

  final String engine;
  final String? recognitionId;
  final String? appVersion;
  final String? ocrPkgVersion;
  final String? cardLanguage;
  final String? region;
  final List<Map<String, dynamic>> rawOcrLines;
  final Map<String, dynamic>? parsedResult;
  final Map<String, dynamic>? confidence;
  final String? imagePath;
}
