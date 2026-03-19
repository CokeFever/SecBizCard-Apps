import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _companyController;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _companyController = TextEditingController();
    _titleController = TextEditingController();

    // Initialize controller with current user data if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(authRepositoryProvider).getCurrentUser();

      // We ideally want to initialize the drafted profile with at least the Auth info
      // if it hasn't been initialized yet.
      if (currentUser != null) {
        final initialProfile = UserProfile(
          uid: currentUser.uid,
          email: currentUser.email ?? '',
          displayName: currentUser.displayName ?? '',
          photoUrl: currentUser.photoURL,
          createdAt: DateTime.now(),
        );
        ref.read(onboardingControllerProvider.notifier).init(initialProfile);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _syncControllersWithState(OnboardingState state) {
    if (state.draftProfile != null) {
      if (_nameController.text != state.draftProfile!.displayName) {
        _nameController.text = state.draftProfile!.displayName;
      }
      if (_emailController.text != (state.draftProfile!.email ?? '')) {
        _emailController.text = state.draftProfile!.email ?? '';
      }
      if (state.draftProfile!.phone != null &&
          _phoneController.text != state.draftProfile!.phone) {
        _phoneController.text = state.draftProfile!.phone!;
      }
      if (state.draftProfile!.company != null &&
          _companyController.text != state.draftProfile!.company) {
        _companyController.text = state.draftProfile!.company!;
      }
      if (state.draftProfile!.title != null &&
          _titleController.text != state.draftProfile!.title) {
        _titleController.text = state.draftProfile!.title!;
      }
    }
  }

  void _updateDraft() {
    final state = ref.read(onboardingControllerProvider);
    if (state.draftProfile != null) {
      final updated = state.draftProfile!.copyWith(
        displayName: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
        company: _companyController.text.isNotEmpty
            ? _companyController.text
            : null,
        title: _titleController.text.isNotEmpty ? _titleController.text : null,
      );
      ref.read(onboardingControllerProvider.notifier).updateDraft(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    // Sync controllers only when stepping into Edit step or after import
    // Simple check: if controllers are empty and draft is not, sync.
    // Or just listen to changes. For simplicity we sync when entering the step.
    if (state.currentStep == 1 &&
        _nameController.text.isEmpty &&
        state.draftProfile != null) {
      _syncControllersWithState(state);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Setup Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide back button
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (state.currentStep + 1) / 4,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildStep(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(OnboardingState state) {
    switch (state.currentStep) {
      case 0:
        return _buildImportStep(state);
      case 1:
        return _buildReviewStep(state);
      case 2:
        return _buildContextStep(state);
      case 3:
        return _buildFinishStep(state);
      default:
        return const SizedBox();
    }
  }

  Widget _buildImportStep(OnboardingState state) {
    final notifier = ref.read(onboardingControllerProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.import_contacts,
          size: 80,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 32),
        Text(
          'Get Started Quickly',
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Import your profile from your Google Contact card to skip manual entry.',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        if (state.isLoading)
          const CircularProgressIndicator()
        else ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => notifier.importFromGoogle(),
              icon: const Icon(Icons.cloud_download),
              label: const Text('Import from Google'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => notifier.skipImport(),
            child: Text(
              'Enter Manually',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildReviewStep(OnboardingState state) {
    final notifier = ref.read(onboardingControllerProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Info',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This info will be your "Master Profile". You can choose what to share later.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Using your Personal Phone & Gmail is recommended for account recovery and verified trust.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildTextField(
            controller: _nameController,
            label: 'Full Name (Required)',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone (Optional)',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email (Optional)',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
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

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                // Update draft and go next
                _updateDraft();
                if (_nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                notifier.nextStep();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextStep(OnboardingState state) {
    final notifier = ref.read(onboardingControllerProvider.notifier);
    // Visual Guide only for MVP Sprint 8

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Smart Contexts',
          style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'We have set up 3 default contexts for you. You can customize them anytime in Settings.',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),

        _buildContextCard(
          title: 'Business',
          icon: Icons.business_center,
          color: Colors.blue,
          description: 'Shares: Name, Job Title, Company, Phone, Email',
        ),
        const SizedBox(height: 16),
        _buildContextCard(
          title: 'Social',
          icon: Icons.person,
          color: Colors.purple,
          description: 'Shares: Name, Personal Email, Avatar',
        ),
        const SizedBox(height: 16),
        _buildContextCard(
          title: 'Lite',
          icon: Icons.flash_on,
          color: Colors.orange,
          description: 'Shares: Name only',
        ),

        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => notifier.nextStep(),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Looks Good'),
          ),
        ),
      ],
    );
  }

  Widget _buildContextCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildFinishStep(OnboardingState state) {
    final notifier = ref.read(onboardingControllerProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 80, color: Colors.green),
        const SizedBox(height: 32),
        Text(
          'You are all set!',
          style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your digital business card is ready to share.',
          style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        if (state.isLoading)
          const CircularProgressIndicator()
        else
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                final success = await notifier.completeOnboarding();
                if (success && mounted) {
                  context.go('/home');
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.green,
              ),
              child: const Text('Start Using IXO'),
            ),
          ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              state.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: GoogleFonts.inter(),
      keyboardType: keyboardType,
    );
  }
}
