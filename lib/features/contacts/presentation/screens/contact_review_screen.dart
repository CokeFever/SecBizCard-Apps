import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/contacts/data/contacts_repository.dart';

class ContactReviewScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  final String imagePath;

  const ContactReviewScreen({
    super.key,
    required this.profile,
    required this.imagePath,
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
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _emailController = TextEditingController(text: widget.profile.email);
    _companyController = TextEditingController(text: widget.profile.company);
    _titleController = TextEditingController(text: widget.profile.title);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _addressController = TextEditingController(text: widget.profile.address);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveContact() async {
    final updatedProfile = widget.profile.copyWith(
      displayName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      company: _companyController.text.trim(),
      title: _titleController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Contact'),
        actions: [
          IconButton(onPressed: _saveContact, icon: const Icon(Icons.check)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Scanned image preview
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
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
                    _addressController,
                    'Address',
                    Icons.location_on,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
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
