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

import 'package:secbizcard/features/storage/data/drive_repository.dart';

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
  bool _isUploadingImage = false;

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
    });
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

        // Local Storage Mode: Skip upload
        // Just store the local path and clear the remote ID
        avatarDriveFileId = null;
        // The path will be picked up by the updatedUser creation logic below
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
        phone: newPhone.isEmpty ? null : newPhone,
        avatarDriveFileId: avatarDriveFileId,
        // Fallback to local path if upload failed but image selected
        photoUrl: (_selectedImage != null && avatarDriveFileId == null)
            ? _selectedImage!.path
            : widget.user.photoUrl,
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

    return Scaffold(
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
            onPressed: isSaving ? null : _save,
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
            ],
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
                backgroundImage: backgroundImage,
                child: backgroundImage == null
                    ? Icon(Icons.person, size: 60, color: theme.hintColor)
                    : null,
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

  // Use shared FieldFormatter
  IconData _getIconForInfoType(String key) => FieldFormatter.getIcon(key);

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
