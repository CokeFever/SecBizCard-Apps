import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:secbizcard/core/utils/field_formatter.dart';
import 'package:secbizcard/core/utils/dialog_utils.dart';
import 'package:secbizcard/core/presentation/widgets/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:secbizcard/features/storage/data/drive_repository.dart';
import 'dart:io';

class EditContactScreen extends ConsumerStatefulWidget {
  final UserProfile user;

  const EditContactScreen({super.key, required this.user});

  @override
  ConsumerState<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends ConsumerState<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _titleController;
  late TextEditingController _companyController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  File? _cardFrontImage;
  File? _cardBackImage;
  bool _isCardFrontRemoved = false;
  bool _isCardBackRemoved = false;

  // For dynamic fields
  final Map<String, TextEditingController> _customFieldControllers = {};

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

  bool _isSaving = false;

  bool get _hasChanges {
    if (_cardFrontImage != null) return true;
    if (_cardBackImage != null) return true;
    if (_isCardFrontRemoved) return true;
    if (_isCardBackRemoved) return true;

    if (_nameController.text.trim() != widget.user.displayName) return true;
    if (_nicknameController.text.trim() != (widget.user.customFields['Nickname'] ?? '')) return true;
    if (_titleController.text.trim() != (widget.user.title ?? '')) return true;
    if (_companyController.text.trim() != (widget.user.company ?? '')) return true;
    if (_phoneController.text.trim() != (widget.user.phone ?? '')) return true;
    if (_emailController.text.trim() != (widget.user.email ?? '')) return true;

    // Compare custom fields
    final currentCustomFields = <String, String>{};
    _customFieldControllers.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        currentCustomFields[key] = value;
      }
    });

    // Initial custom fields without Nickname
    final initialCustomFields = Map<String, String>.from(widget.user.customFields)..remove('Nickname');

    if (currentCustomFields.length != initialCustomFields.length) return true;

    for (var entry in currentCustomFields.entries) {
      if (initialCustomFields[entry.key] != entry.value) return true;
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _nicknameController = TextEditingController(
      text: widget.user.customFields['Nickname'] ?? '',
    );
    _titleController = TextEditingController(text: widget.user.title);
    _companyController = TextEditingController(text: widget.user.company);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email);

    widget.user.customFields.forEach((key, value) {
      if (key != 'Nickname') {
        _customFieldControllers[key] = TextEditingController(text: value);
        _customFieldControllers[key]!.addListener(_onFieldChanged);
      }
    });

    _nameController.addListener(_onFieldChanged);
    _nicknameController.addListener(_onFieldChanged);
    _titleController.addListener(_onFieldChanged);
    _companyController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {}); // Trigger rebuild to update save button
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    for (var controller in _customFieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addCustomField() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddFieldDialog(fieldTypes: _fieldTypes),
    );

    if (result != null) {
      final category = result['category']!;
      final label = result['label']!;

      String baseKey = '${category.toLowerCase()}_${label.toLowerCase()}';
      String key = baseKey;
      int counter = 2;

      while (_customFieldControllers.containsKey(key)) {
        key = '${baseKey}_$counter';
        counter++;
      }

      setState(() {
        _customFieldControllers[key] = TextEditingController();
        _customFieldControllers[key]!.addListener(_onFieldChanged);
      });
    }
  }

  void _removeCustomField(String key) {
    setState(() {
      _customFieldControllers[key]?.dispose();
      _customFieldControllers.remove(key);
    });
  }

  // Use shared FieldFormatter
  String _formatFieldLabel(String key) => FieldFormatter.formatLabel(key);
  IconData _getIconForInfoType(String key) => FieldFormatter.getIcon(key);

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      // Start with empty map related to dynamic fields logic?
      // No, start with PREVIOUS custom fields but remove deleted ones?
      // Actually, my `_customFieldControllers` represents the CURRENT state of ALL custom fields (except Nickname).
      // So I should construct the map from `_customFieldControllers`.

      final Map<String, String> updatedCustomFields = {};

      // Add Nickname
      final nickname = _nicknameController.text.trim();
      if (nickname.isNotEmpty) {
        updatedCustomFields['Nickname'] = nickname;
      }

      // Add Dynamic Fields
      _customFieldControllers.forEach((key, controller) {
        if (controller.text.trim().isNotEmpty) {
          updatedCustomFields[key] = controller.text.trim();
        }
      });

      final updatedProfile = widget.user.copyWith(
        displayName: _nameController.text.trim(),
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        company: _companyController.text.trim().isEmpty
            ? null
            : _companyController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim(),
        cardFrontPath: _isCardFrontRemoved
            ? null
            : (_cardFrontImage != null)
                ? _cardFrontImage!.path
                : (widget.user.cardFrontPath ?? widget.user.flatImagePath),
        cardFrontDriveFileId: _isCardFrontRemoved ? null : widget.user.cardFrontDriveFileId,
        cardBackPath: _isCardBackRemoved
            ? null
            : (_cardBackImage != null)
                ? _cardBackImage!.path
                : widget.user.cardBackPath,
        cardBackDriveFileId: _isCardBackRemoved ? null : widget.user.cardBackDriveFileId,
        customFields: updatedCustomFields,
      );

      final repo = ref.read(contactsRepositoryProvider);
      final result = await repo.saveContactLocally(updatedProfile);

      if (!mounted) return;

      result.fold(
        (l) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${l.message}')));
        },
        (r) {
          ref.invalidate(savedContactsProvider);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Contact updated')));
          context.pop(updatedProfile);
        },
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChanges = _hasChanges;

    return PopScope(
      canPop: !hasChanges || _isSaving,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool shouldPop = await DialogUtils.showUnsavedChangesDialog(context) ?? false;
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Contact'),
          actions: [
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              onPressed: (_isSaving || !hasChanges) ? null : _save,
            ),
          ],
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Basic Info',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nameController,
                'Display Name',
                Icons.person,
                required: true,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nicknameController,
                'Nickname (Only visible to you)',
                Icons.label_outline,
              ),
              const SizedBox(height: 24),

              Text(
                'Job Info',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _titleController,
                'Job Title',
                Icons.work_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(_companyController, 'Company', Icons.business),
              const SizedBox(height: 24),

              Text(
                'Contact',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _phoneController,
                'Phone',
                Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _emailController,
                'Email',
                Icons.email,
                keyboardType: TextInputType.emailAddress,
                required: true,
              ),
              const SizedBox(height: 24),

              if (_customFieldControllers.isNotEmpty) ...[
                Text(
                  'Additional Info',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                            entry.value,
                            _formatFieldLabel(entry.key),
                            _getIconForInfoType(entry.key),
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
              _buildBusinessCardsSection(),
              const SizedBox(height: 32),
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
    bool required = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
          : null,
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

  Widget _buildBusinessCardsSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
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
                remotePath: widget.user.cardFrontPath ?? widget.user.flatImagePath,
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

  // Simplified version for EditContact since we already have logic in EditProfile
  // I'll make it consistent
  Widget _buildUnitializedCardPicker() {
      return Expanded(
              child: _buildCardPicker(
                label: 'Back Side',
                imageFile: _cardBackImage,
                remotePath: widget.user.cardBackPath,
                onTap: () => _pickCardImage(false),
                onRemove: () => setState(() {
                  _cardBackImage = null;
                }),
              ),
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
        // We'll need driveRepo here. I'll add driveRepositoryProvider import if needed, 
        // but let's check if it's already there.
        // It's a ConsumerStatefulWidget so we have ref.
        // Wait, I need to check imports.
        imageProvider = CachedNetworkImageProvider(
          ref.read(driveRepositoryProvider).getFileUrl(driveFileId)
        );
        currentHeroPath = driveFileId; // Hero tag needs a unique string
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
