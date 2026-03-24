import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/core/utils/image_picker_service.dart';
import 'package:secbizcard/core/utils/async_value_ui.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:intl/intl.dart';
import 'package:secbizcard/core/utils/field_formatter.dart';
import 'package:secbizcard/core/utils/dialog_utils.dart';

import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'package:secbizcard/core/presentation/widgets/full_screen_image_viewer.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _phoneController;

  late FocusNode _phoneFocusNode;
  bool _isPhoneModified = false;

  // For dynamic fields
  late Map<String, TextEditingController> _customFieldControllers;
  final Map<String, FocusNode> _customFieldFocusNodes = {};
  String? _lastAddedFieldKey;

  // Available field types
  final Map<String, List<String>> _fieldTypes = {
    'Phone': ['Work', 'Home', 'Mobile', 'Fax', 'Other'],
    'Email': ['Work', 'Personal', 'Other'],
    'Address': ['Work', 'Home', 'Other'],
    'Website': ['Personal', 'Company', 'Blog', 'Portfolio'],
    'Social': ['LinkedIn', 'Twitter', 'Facebook', 'Instagram', 'GitHub'],
    'Date': ['Birthday', 'Anniversary'],
    'Note': ['General'],
  };

  File? _selectedImage;
  File? _cardFrontImage;
  File? _cardBackImage;
  bool _isCardFrontRemoved = false;
  bool _isCardBackRemoved = false;
  bool _isAvatarRemoved = false;
  bool _isUploadingImage = false;

  bool get _hasChanges {
    if (_cardFrontImage != null) return true;
    if (_cardBackImage != null) return true;
    if (_selectedImage != null) return true;
    if (_isAvatarRemoved) return true;
    if (_isCardFrontRemoved) return true;
    if (_isCardBackRemoved) return true;

    if (_nameController.text.trim() != widget.user.displayName) return true;
    if (_titleController.text.trim() != (widget.user.title ?? '')) return true;
    if (_companyController.text.trim() != (widget.user.company ?? '')) return true;
    if (_phoneController.text.trim() != (widget.user.phone ?? '')) return true;

    // Compare custom fields
    final currentCustomFields = <String, String>{};
    _customFieldControllers.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        currentCustomFields[key] = value;
      }
    });

    if (currentCustomFields.length != widget.user.customFields.length) return true;

    for (var entry in currentCustomFields.entries) {
      if (widget.user.customFields[entry.key] != entry.value) return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.user.displayName);
    _titleController = TextEditingController(text: widget.user.title);
    _companyController = TextEditingController(text: widget.user.company);
    _phoneController = TextEditingController(text: widget.user.phone);
    _phoneFocusNode = FocusNode();
    _phoneFocusNode.addListener(_onPhoneFocusChange);

    _customFieldControllers = {};
    widget.user.customFields.forEach((key, value) {
      _customFieldControllers[key] = TextEditingController(text: value);
      _customFieldControllers[key]!.addListener(_onFieldChanged);
    });

    _nameController.addListener(_onFieldChanged);
    _titleController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {}); // Trigger rebuild to update save button state
  }

  void _onPhoneFocusChange() {
    if (!_phoneFocusNode.hasFocus) {
      final newPhone = _phoneController.text.trim();
      final oldPhone = widget.user.phone ?? '';
      final isModified = newPhone != oldPhone;

      if (isModified != _isPhoneModified) {
        setState(() {
          _isPhoneModified = isModified;
        });

        if (isModified && widget.user.phoneVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ Verified phone modified. Verification will be reset on save.',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneFocusNode.dispose();

    _nameController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    for (var controller in _customFieldControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _customFieldFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Widget _buildVerifiableField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required bool isVerified,
    FocusNode? focusNode,
  }) {
    final theme = Theme.of(context);
    // If phone is modified, treat as not verified for UI display
    final showVerified = isVerified && !_isPhoneModified;

    return Focus(
      onFocusChange: (hasFocus) {
        // We handle focus logic in the controller/listener mostly
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon, color: theme.hintColor),
                  suffixIcon: showVerified
                      ? const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 20,
                        )
                      : null,
                ),
                style: GoogleFonts.inter(
                  color: theme.textTheme.bodyMedium?.color,
                ),
                keyboardType: keyboardType,
              ),
              if (showVerified && hasFocus)
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text(
                    '⚠️ Modifying this will require re-verification',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final imagePickerService = ref.read(imagePickerServiceProvider);
    final result = source == ImageSource.gallery
        ? await imagePickerService.pickImageFromGallery()
        : await imagePickerService.pickImageFromCamera();

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (image) {
        _cropImage(image);
      },
    );
  }

  Future<void> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      // aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Optional: force square
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Edit Photo',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Edit Photo'),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _selectedImage = File(croppedFile.path);
        _isAvatarRemoved = false;
      });
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomField() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddFieldDialog(fieldTypes: _fieldTypes),
    );

    if (result != null) {
      final category = result['category']!;
      final label = result['label']!;

      // Generate key: category_label (lowercase)
      // e.g. phone_work, email_personal
      String baseKey = '${category.toLowerCase()}_${label.toLowerCase()}';
      String key = baseKey;
      int counter = 2;

      // Handle duplicates
      while (_customFieldControllers.containsKey(key)) {
        key = '${baseKey}_$counter';
        counter++;
      }

      setState(() {
        _customFieldControllers[key] = TextEditingController();
        _customFieldControllers[key]!.addListener(_onFieldChanged);
        _customFieldFocusNodes[key] = FocusNode();
        _lastAddedFieldKey = key;
      });

      // Focus the new field after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lastAddedFieldKey != null &&
            _customFieldFocusNodes[_lastAddedFieldKey!] != null) {
          _customFieldFocusNodes[_lastAddedFieldKey!]!.requestFocus();
          _lastAddedFieldKey = null;
        }
      });
    }
  }

  // Use shared FieldFormatter
  String _formatFieldLabel(String key) => FieldFormatter.formatLabel(key);


  void _removeCustomField(String key) {
    setState(() {
      _customFieldControllers[key]?.dispose();
      _customFieldControllers.remove(key);
      _customFieldFocusNodes[key]?.dispose();
      _customFieldFocusNodes.remove(key);
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      String? avatarDriveFileId = widget.user.avatarDriveFileId;

      // Upload new avatar if selected
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });
        avatarDriveFileId = null;
      }

      // Collect custom fields
      final Map<String, String> customFields = {};
      _customFieldControllers.forEach((key, controller) {
        if (controller.text.trim().isNotEmpty) {
          customFields[key] = controller.text.trim();
        }
      });

      // Check if verified phone was modified
      final newPhone = _phoneController.text.trim();
      final oldPhone = widget.user.phone ?? '';
      final phoneChanged = newPhone != oldPhone;
      final wasPhoneVerified = widget.user.phoneVerified;

      // If phone was verified and is now changed, ask for confirmation
      if (phoneChanged && wasPhoneVerified) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verification Will Be Reset'),
            content: const Text(
              'You are changing a verified phone number. '
              'This will reset the verification status and you will need to verify the new number.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Continue'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          return; // User cancelled
        }
      }

      final updatedUser = widget.user.copyWith(
        displayName: _nameController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        company: _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
        department: widget.user.department,
        phone: newPhone.isEmpty ? null : newPhone,
        avatarDriveFileId: _isAvatarRemoved ? null : avatarDriveFileId,
        photoUrl: _isAvatarRemoved
            ? null
            : (_selectedImage != null)
                ? _selectedImage!.path
                : widget.user.photoUrl,
        cardFrontPath: _isCardFrontRemoved
            ? null
            : (_cardFrontImage != null)
                ? _cardFrontImage!.path
                : widget.user.cardFrontPath,
        cardFrontDriveFileId: _isCardFrontRemoved ? null : widget.user.cardFrontDriveFileId,
        cardBackPath: _isCardBackRemoved
            ? null
            : (_cardBackImage != null)
                ? _cardBackImage!.path
                : widget.user.cardBackPath,
        cardBackDriveFileId: _isCardBackRemoved ? null : widget.user.cardBackDriveFileId,
        customFields: customFields,
        // Reset phone verification if phone was changed
        phoneVerified: (phoneChanged && wasPhoneVerified)
            ? false
            : widget.user.phoneVerified,
        phoneVerifiedAt: (phoneChanged && wasPhoneVerified)
            ? null
            : widget.user.phoneVerifiedAt,
      );

      ref.read(editProfileControllerProvider.notifier).saveProfile(updatedUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editProfileControllerProvider, (previous, next) {
      next.showSnackbarOnError(context);
      if (!next.isLoading && !next.hasError) {
        // Success - invalidate profile provider to refresh data
        ref.invalidate(userProfileProvider);
        context.pop();
      }
    });

    final state = ref.watch(editProfileControllerProvider);
    final isSaving = state.isLoading || _isUploadingImage;
    final theme = Theme.of(context);
    final hasChanges = _hasChanges;

    return PopScope(
      canPop: !hasChanges || isSaving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool shouldPop = await DialogUtils.showUnsavedChangesDialog(context) ?? false;
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Edit Profile',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: (isSaving || !hasChanges) ? null : _save,
            ),
          ],
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar section
              _buildAvatarSection(),
              const SizedBox(height: 32),

              const SizedBox(height: 24),

              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _titleController,
                label: 'Job Title',
                icon: Icons.work,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _companyController,
                label: 'Company',
                icon: Icons.business,
              ),
              const SizedBox(height: 16),
              // Phone field with verification indicator
              _buildVerifiableField(
                controller: _phoneController,
                label: 'Phone',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                isVerified: widget.user.phoneVerified,
                focusNode: _phoneFocusNode,
              ),
              const SizedBox(height: 24),
              // Dynamic Fields Section
              if (_customFieldControllers.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Additional Info',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ..._customFieldControllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: entry.value,
                            label: _formatFieldLabel(entry.key),
                            icon: FieldFormatter.getIcon(entry.key),
                            focusNode: _customFieldFocusNodes[entry.key],
                            readOnly: entry.key.toLowerCase().contains('birthday') || 
                                     entry.key.toLowerCase().contains('date'),
                            onTap: (entry.key.toLowerCase().contains('birthday') || 
                                     entry.key.toLowerCase().contains('date'))
                                ? () => _selectDate(context, entry.value)
                                : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeCustomField(entry.key),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              OutlinedButton.icon(
                onPressed: _addCustomField,
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: BorderSide(color: theme.dividerColor),
                ),
              ),
              const SizedBox(height: 32),
              _buildCardImagesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildAvatarSection() {
    final driveRepo = ref.read(driveRepositoryProvider);
    final theme = Theme.of(context);

    // Helper for complex image logic
    ImageProvider? backgroundImage;
    if (_selectedImage != null) {
      backgroundImage = FileImage(_selectedImage!);
    } else if (widget.user.avatarDriveFileId != null) {
      backgroundImage = CachedNetworkImageProvider(
        driveRepo.getFileUrl(widget.user.avatarDriveFileId!),
      );
    } else if (widget.user.photoUrl != null) {
      if (widget.user.photoUrl!.startsWith('http')) {
        backgroundImage = CachedNetworkImageProvider(widget.user.photoUrl!);
      } else {
        backgroundImage = FileImage(File(widget.user.photoUrl!));
      }
    } else {
      final authUser = ref.read(authRepositoryProvider).getCurrentUser();
      if (authUser?.photoURL != null) {
        backgroundImage = CachedNetworkImageProvider(authUser!.photoURL!);
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: theme.canvasColor,
                backgroundImage: _isAvatarRemoved ? null : backgroundImage,
                child: (_isAvatarRemoved || backgroundImage == null)
                    ? Icon(Icons.person, size: 60, color: theme.hintColor)
                    : null,
              ),
              if (!_isAvatarRemoved && (backgroundImage != null))
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedImage = null;
                      _isAvatarRemoved = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to change photo',
          style: TextStyle(color: theme.hintColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    FocusNode? focusNode,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.hintColor),
        suffixIcon: suffixIcon,
      ),
      style: GoogleFonts.inter(color: theme.textTheme.bodyMedium?.color),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateFormat('yyyy/MM/dd').parse(controller.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy/MM/dd').format(picked);
      });
    }
  }


  Widget _buildCardImagesSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Cards',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildCardPicker(
                label: 'Front Side',
                imageFile: _cardFrontImage,
                remotePath: widget.user.cardFrontPath,
                driveFileId: widget.user.cardFrontDriveFileId,
                isExplicitlyRemoved: _isCardFrontRemoved,
                onTap: () => _pickCardImage(true),
                onRemove: () => setState(() {
                  _cardFrontImage = null;
                  _isCardFrontRemoved = true;
                }),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildCardPicker(
                label: 'Back Side',
                imageFile: _cardBackImage,
                remotePath: widget.user.cardBackPath,
                driveFileId: widget.user.cardBackDriveFileId,
                isExplicitlyRemoved: _isCardBackRemoved,
                onTap: () => _pickCardImage(false),
                onRemove: () => setState(() {
                  _cardBackImage = null;
                  _isCardBackRemoved = true;
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardPicker({
    required String label,
    required File? imageFile,
    required String? remotePath,
    required String? driveFileId,
    required bool isExplicitlyRemoved,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    final driveRepo = ref.read(driveRepositoryProvider);
    
    ImageProvider? imageProvider;
    String? currentHeroPath;

    if (imageFile != null) {
      imageProvider = FileImage(imageFile);
      currentHeroPath = imageFile.path;
    } else if (!isExplicitlyRemoved) {
      // 1. Try local path if file exists
      if (remotePath != null && remotePath.isNotEmpty) {
        if (remotePath.startsWith('http')) {
          imageProvider = CachedNetworkImageProvider(remotePath);
          currentHeroPath = remotePath;
        } else {
          final file = File(remotePath);
          if (file.existsSync()) {
            imageProvider = FileImage(file);
            currentHeroPath = remotePath;
          }
        }
      }
      
      // 2. Fallback to Drive ID if local path is missing/dead
      if (imageProvider == null && driveFileId != null && driveFileId.isNotEmpty) {
        final url = driveRepo.getFileUrl(driveFileId);
        imageProvider = CachedNetworkImageProvider(url);
        currentHeroPath = url;
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: imageProvider != null
              ? () {
                  final String currentTag = 'card_edit_${currentHeroPath!}';
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                        imagePath: currentHeroPath!,
                        tag: currentTag,
                      ),
                    ),
                  );
                }
              : onTap,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: imageProvider == null ? theme.colorScheme.surfaceVariant.withOpacity(0.5) : theme.canvasColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: imageProvider == null ? theme.colorScheme.primary.withOpacity(0.2) : theme.dividerColor,
                width: imageProvider == null ? 2 : 1,
                style: imageProvider == null ? BorderStyle.solid : BorderStyle.solid,
              ),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined, 
                          color: theme.colorScheme.primary.withOpacity(0.6),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload $label',
                          style: TextStyle(
                            color: theme.colorScheme.primary.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                      children: [
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        // Add an "Edit" overlay or just use the tap to view
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: onTap,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: theme.hintColor, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _pickCardImage(bool isFront) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
    );

    if (image != null) {
      setState(() {
        if (isFront) {
          _cardFrontImage = File(image.path);
          _isCardFrontRemoved = false;
        } else {
          _cardBackImage = File(image.path);
          _isCardBackRemoved = false;
        }
      });
    }
  }
}

class _AddFieldDialog extends StatefulWidget {
  final Map<String, List<String>> fieldTypes;

  const _AddFieldDialog({required this.fieldTypes});

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  String? _selectedCategory;
  String? _selectedLabel;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.fieldTypes.keys.first;
    _selectedLabel = widget.fieldTypes[_selectedCategory]!.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Field'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(labelText: 'Type'),
            items: widget.fieldTypes.keys.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
                _selectedLabel = widget.fieldTypes[value]!.first;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedLabel,
            decoration: const InputDecoration(labelText: 'Label'),
            items: widget.fieldTypes[_selectedCategory]!.map((label) {
              return DropdownMenuItem(value: label, child: Text(label));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedLabel = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'category': _selectedCategory!,
              'label': _selectedLabel!,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
