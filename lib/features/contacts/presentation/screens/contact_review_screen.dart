import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/core/responsive/adaptive_container.dart';
import 'package:secbizcard/core/responsive/breakpoints.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/contacts/data/recognition_quality.dart';
import 'package:secbizcard/features/contacts/data/ocr_feedback_service.dart';
import 'package:secbizcard/features/contacts/presentation/widgets/ocr_feedback_dialogs.dart';

class ContactReviewScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  final String imagePath;

  // Optional OCR metadata for the "report bad recognition" flow. Null when the
  // screen is reached from a path that doesn't carry it.
  final String? ocrEngine;
  final String? ocrRecognitionId;
  final List<Map<String, dynamic>>? ocrRawLines;
  final double? ocrDetectionScore;
  final bool? ocrDetectionFallback;
  final double? ocrBestNameScore;
  final double? ocrAreaRatio;

  /// Clockwise degrees (0/90/180/270) the server said the capture needed to be
  /// rotated so its text is upright. Non-zero => the raw capture was misoriented
  /// (a quality signal for the feedback predictor). Null/0 when not applicable.
  final int? ocrOrientation;

  /// Detected card language (`english`/`chinese`/`japanese`/`korean`) and
  /// region (ISO-3166 alpha-2, e.g. `TW`) — feedback metadata. Null when
  /// undetermined or reached from a path without OCR metadata.
  final String? ocrCardLanguage;
  final String? ocrRegion;

  const ContactReviewScreen({
    super.key,
    required this.profile,
    required this.imagePath,
    this.ocrEngine,
    this.ocrRecognitionId,
    this.ocrRawLines,
    this.ocrDetectionScore,
    this.ocrDetectionFallback,
    this.ocrBestNameScore,
    this.ocrAreaRatio,
    this.ocrOrientation,
    this.ocrCardLanguage,
    this.ocrRegion,
  });

  @override
  ConsumerState<ContactReviewScreen> createState() =>
      _ContactReviewScreenState();
}

class _ContactReviewScreenState extends ConsumerState<ContactReviewScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _companyController;
  late TextEditingController _titleController;
  late TextEditingController _phoneController;
  late TextEditingController _mobileController;
  late TextEditingController _faxController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _taxIdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _emailController = TextEditingController(text: widget.profile.email);
    _companyController = TextEditingController(text: widget.profile.company);
    _titleController = TextEditingController(text: widget.profile.title);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _mobileController = TextEditingController(text: widget.profile.mobile);
    _faxController = TextEditingController(
      text: widget.profile.customFields['fax'],
    );
    _websiteController = TextEditingController(text: widget.profile.website);
    _addressController = TextEditingController(text: widget.profile.address);
    _taxIdController = TextEditingController(
      text: widget.profile.customFields['taxId'],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _faxController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    // Merge the (editable) fax back into customFields.
    final mergedCustomFields = Map<String, String>.from(
      widget.profile.customFields,
    );
    final fax = _faxController.text.trim();
    if (fax.isEmpty) {
      mergedCustomFields.remove('fax');
    } else {
      mergedCustomFields['fax'] = fax;
    }
    final taxId = _taxIdController.text.trim();
    if (taxId.isEmpty) {
      mergedCustomFields.remove('taxId');
    } else {
      mergedCustomFields['taxId'] = taxId;
    }

    final updatedProfile = widget.profile.copyWith(
      displayName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      company: _companyController.text.trim(),
      title: _titleController.text.trim(),
      phone: _phoneController.text.trim(),
      mobile: _mobileController.text.trim(),
      website: _websiteController.text.trim(),
      address: _addressController.text.trim(),
      customFields: mergedCustomFields,
    );

    final result = await ref
        .read(contactsRepositoryProvider)
        .saveContactLocally(updatedProfile);

    if (mounted) {
      result.fold(
        (failure) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${failure.message}'))),
        (_) {
          ref.invalidate(savedContactsProvider);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Contact saved!')));
          // Navigate back to contacts list
          context.go('/home');
        },
      );
    }
  }

  bool _feedbackHandled = false;
  final _feedbackService = OcrFeedbackService();

  /// True if the recognition looked poor (per the predictor over the metadata
  /// carried from the scan screen). Used to decide whether to offer the report
  /// prompt when the user leaves without saving.
  bool get _recognitionLikelyPoor {
    return predictLikelyPoorRecognition(RecognitionSignals(
      detectionFallback: widget.ocrDetectionFallback,
      detectionScore: widget.ocrDetectionScore,
      bestNameScore: widget.ocrBestNameScore,
      coverageRatio: widget.ocrAreaRatio,
      // The server had to rotate the capture upright => it was tilted/flipped,
      // which the geometry score alone can miss. Feeds the ambiguous-zone rule.
      orientationMismatch:
          widget.ocrOrientation != null && widget.ocrOrientation != 0,
      hasName: widget.profile.displayName.trim().isNotEmpty,
      hasAnyPhone: (widget.profile.phone?.isNotEmpty ?? false) ||
          (widget.profile.mobile?.isNotEmpty ?? false),
      nameLooksSuspicious: _nameLooksSuspicious(),
    ));
  }

  /// Content sanity on the chosen Name: catches the "confidently wrong" case
  /// where a high-scoring candidate won the name slot but is actually a job
  /// title (score-based signals miss this). Two cheap, low-false-positive
  /// checks: the Name duplicates the Title field, or the whole Name reads as a
  /// job-title phrase (every word is a title keyword/modifier).
  bool _nameLooksSuspicious() {
    final name = widget.profile.displayName.trim();
    if (name.isEmpty) return false;

    // (a) Name == Title (case-insensitive) — the exact Kantar failure.
    final title = widget.profile.title?.trim() ?? '';
    if (title.isNotEmpty && name.toLowerCase() == title.toLowerCase()) {
      return true;
    }

    // (b) The Name is a pure job-title phrase (Latin). Every word is a title
    //     keyword or a common title modifier. Kept English-only + short to
    //     avoid false positives on real (esp. CJK) names.
    const titleWords = {
      'manager', 'director', 'ceo', 'cto', 'cfo', 'coo', 'cio',
      'engineer', 'developer', 'designer', 'architect', 'founder',
      'president', 'vp', 'officer', 'chief', 'consultant', 'advisor',
      'analyst', 'coordinator', 'specialist', 'associate', 'supervisor',
      'lead', 'head', 'partner', 'principal', 'representative', 'executive',
      'assistant', 'secretary', 'managing', 'vice', 'senior', 'junior',
      'staff', 'global', 'regional', 'technical', 'sales', 'marketing',
      'product', 'strategic', 'business', 'general', 'deputy', 'operating',
      'operations',
    };
    final words = name
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[.,]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isNotEmpty &&
        words.length <= 4 &&
        words.every(titleWords.contains)) {
      return true;
    }
    return false;
  }

  /// Called on Back. If recognition looked poor, offer the (opt-in) report
  /// prompt, then let the pop proceed. Returns after any dialog completes.
  Future<void> _handleLeave() async {
    if (_feedbackHandled) return;
    _feedbackHandled = true;
    // Only for shared-key / own-key with raw lines available, and only when the
    // result looked poor. Nothing here blocks leaving.
    if (widget.ocrRawLines == null || widget.ocrRawLines!.isEmpty) return;
    if (!_recognitionLikelyPoor) return;
    if (!mounted) return;

    final proceed =
        await OcrFeedbackDialogs.maybePromptOnLeave(context, _feedbackService);
    if (!proceed || !mounted) return;

    await OcrFeedbackDialogs.showConsentAndSubmit(
      context,
      _feedbackService,
      OcrFeedbackSample(
        engine: widget.ocrEngine ?? 'unknown',
        recognitionId: widget.ocrRecognitionId,
        cardLanguage: widget.ocrCardLanguage,
        region: widget.ocrRegion,
        rawOcrLines: widget.ocrRawLines!,
        parsedResult: {
          'displayName': widget.profile.displayName,
          'company': widget.profile.company,
          'title': widget.profile.title,
          'email': widget.profile.email,
          'phone': widget.profile.phone,
          'mobile': widget.profile.mobile,
          'website': widget.profile.website,
          'address': widget.profile.address,
        },
        confidence: {
          'detectionScore': widget.ocrDetectionScore,
          'detectionFallback': widget.ocrDetectionFallback,
        },
        imagePath: widget.imagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept Back so we can offer the (opt-in) report prompt BEFORE
      // leaving, then pop manually. Saving uses context.go (not pop), so it
      // bypasses this and never triggers the prompt.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleLeave();
        if (mounted && context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Review Contact'),
        actions: [
          IconButton(onPressed: _saveContact, icon: const Icon(Icons.check)),
        ],
      ),
      body: SingleChildScrollView(
        child: AdaptiveContainer(
          maxWidth: Breakpoints.maxContentWidth,
          child: Column(
          children: [
            // Scanned image preview
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  // This is only a preview thumbnail; its width is capped by
                  // AdaptiveContainer (maxContentWidth). Decode to at most that
                  // width in physical pixels so the full-res captured card photo
                  // isn't held in memory. Passing only cacheWidth preserves the
                  // image's aspect ratio.
                  cacheWidth:
                      (Breakpoints.maxContentWidth *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                ),
              ),
            ),


            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(_nameController, 'Name', Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField(_emailController, 'Email', Icons.email),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _companyController,
                    'Company',
                    Icons.business,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_titleController, 'Title', Icons.badge),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'Phone', Icons.phone),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _mobileController,
                    'Mobile',
                    Icons.smartphone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(_faxController, 'Fax', Icons.print),
                  const SizedBox(height: 16),
                  _buildTextField(_websiteController, 'Website', Icons.language),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _addressController,
                    'Address',
                    Icons.location_on,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _taxIdController,
                    'VAT / Tax ID',
                    Icons.receipt_long,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
