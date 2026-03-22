import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:intl/intl.dart';
import 'package:secbizcard/core/utils/field_formatter.dart';

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

  // For dynamic fields
  late Map<String, TextEditingController> _customFieldControllers;

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

    _customFieldControllers = {};
    widget.user.customFields.forEach((key, value) {
      if (key != 'Nickname') {
        _customFieldControllers[key] = TextEditingController(text: value);
      }
    });
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
    return Scaffold(
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
            onPressed: _isSaving ? null : _save,
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
            ],
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
