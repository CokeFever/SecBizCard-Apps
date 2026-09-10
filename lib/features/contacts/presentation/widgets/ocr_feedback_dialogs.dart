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
///  2. [showConsentAndSubmit] — the consent dialog (concise summary + expandable
///     full terms + optional include-photo), then submits via the service.
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

  /// Shows the consent dialog and, on agreement, submits the sample. Shows a
  /// result snackbar. [sample] carries everything the service needs except the
  /// image-consent flag (decided here via the checkbox).
  static Future<void> showConsentAndSubmit(
    BuildContext context,
    OcrFeedbackService service,
    OcrFeedbackSample sample,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    bool includePhoto = false;
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

    if (agreed != true || !context.mounted) return;

    final result = await service.submit(
      engine: sample.engine,
      recognitionId: sample.recognitionId,
      appVersion: sample.appVersion,
      ocrPkgVersion: sample.ocrPkgVersion,
      cardLanguage: sample.cardLanguage,
      region: sample.region,
      rawOcrLines: sample.rawOcrLines,
      parsedResult: sample.parsedResult,
      confidence: sample.confidence,
      // Only send the image path if the user ticked include-photo.
      imagePath: includePhoto ? sample.imagePath : null,
      consentData: true,
      consentImage: includePhoto && sample.imagePath != null,
    );

    if (!context.mounted) return;
    final String msg;
    if (result.limitReached) {
      msg = l10n.ocrFeedbackLimitReached;
    } else if (result.success) {
      msg = result.refunded
          ? l10n.ocrFeedbackThanksRefunded
          : l10n.ocrFeedbackThanks;
    } else {
      msg = l10n.ocrFeedbackFailed;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
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
