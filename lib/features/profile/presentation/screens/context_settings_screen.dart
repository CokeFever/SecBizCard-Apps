import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:secbizcard/features/profile/data/profile_repository.dart';
import 'package:secbizcard/features/profile/domain/card_context.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';

class ContextSettingsScreen extends ConsumerStatefulWidget {
  final UserProfile user;

  const ContextSettingsScreen({super.key, required this.user});

  @override
  ConsumerState<ContextSettingsScreen> createState() =>
      _ContextSettingsScreenState();
}

class _ContextSettingsScreenState extends ConsumerState<ContextSettingsScreen> {
  late Map<ContextType, CardContext> _contexts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize contexts from user profile or use defaults
    _contexts = _parseContextsFromJson(widget.user.contextsJson);
  }

  Map<ContextType, CardContext> _parseContextsFromJson(
    Map<String, dynamic> json,
  ) {
    if (json.isEmpty) {
      return CardContext.createDefaults();
    }

    try {
      // We start with defaults to ensure we have all keys, then merge
      final defaults = CardContext.createDefaults();
      final parsed = <ContextType, CardContext>{};

      for (var type in ContextType.values) {
        if (json.containsKey(type.name)) {
          parsed[type] = CardContext.fromJson(
            json[type.name] as Map<String, dynamic>,
          );
        } else {
          parsed[type] = defaults[type]!;
        }
      }
      return parsed;
    } catch (e) {
      return CardContext.createDefaults();
    }
  }

  void _updateContext(ContextType type, CardContext context) {
    setState(() {
      _contexts[type] = context;
    });
  }

  void _updateCustomFieldVisibility(
    ContextType type,
    String key,
    bool isVisible,
  ) {
    final currentContext = _contexts[type]!;
    final newMap = Map<String, bool>.from(currentContext.showCustomFields);
    newMap[key] = isVisible;

    _updateContext(type, currentContext.copyWith(showCustomFields: newMap));
  }

  Future<void> _saveContexts() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Serialize contexts back to JSON
      final contextsJson = <String, dynamic>{};
      _contexts.forEach((key, value) {
        contextsJson[key.name] = value.toJson();
      });

      final updatedUser = widget.user.copyWith(contextsJson: contextsJson);

      final result = await ref
          .read(profileRepositoryProvider)
          .createOrUpdateUser(updatedUser);

      if (mounted) {
        result.fold(
          (failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving: ${failure.message}')),
            );
          },
          (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contexts saved successfully')),
            );
            Navigator.pop(context);
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Card Contexts',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveContexts,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Customize what information to share in different contexts',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildContextCard(ContextType.business),
          const SizedBox(height: 16),
          _buildContextCard(ContextType.social),
          const SizedBox(height: 16),
          _buildContextCard(ContextType.lite),
        ],
      ),
    );
  }

  Widget _buildContextCard(ContextType type) {
    final cardContext = _contexts[type]!;
    final theme = Theme.of(context);
    final String title;
    final String description;
    final IconData icon;
    final Color color;

    switch (type) {
      case ContextType.business:
        title = 'Business';
        description = 'Full professional information';
        icon = Icons.business_center;
        color = Colors.blue;
        break;
      case ContextType.social:
        title = 'Social';
        description = 'Personal contact without work details';
        icon = Icons.people;
        color = Colors.green;
        break;
      case ContextType.lite:
        title = 'Lite';
        description = 'Minimal information only';
        icon = Icons.person_outline;
        color = Colors.orange;
        break;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      color: theme.cardTheme.color ?? theme.cardColor,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          description,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToggle(
                  'Name',
                  cardContext.showName,
                  (value) => _updateContext(
                    type,
                    cardContext.copyWith(showName: value),
                  ),
                ),
                _buildToggle(
                  'Email',
                  cardContext.showEmail,
                  (value) => _updateContext(
                    type,
                    cardContext.copyWith(showEmail: value),
                  ),
                ),
                _buildToggle(
                  'Phone',
                  cardContext.showPhone,
                  (value) => _updateContext(
                    type,
                    cardContext.copyWith(showPhone: value),
                  ),
                ),
                _buildToggle(
                  'Job Title',
                  cardContext.showTitle,
                  (value) => _updateContext(
                    type,
                    cardContext.copyWith(showTitle: value),
                  ),
                ),
                _buildToggle(
                  'Company',
                  cardContext.showCompany,
                  (value) => _updateContext(
                    type,
                    cardContext.copyWith(showCompany: value),
                  ),
                ),
                _buildToggle(
                  'Avatar',
                  cardContext.showAvatar,
                  (value) => _updateContext(
                    type,
                    cardContext.copyWith(showAvatar: value),
                  ),
                ),

                // Dynamic Fields
                if (widget.user.customFields.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Additional Info',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.user.customFields.keys.map((key) {
                    final isVisible =
                        cardContext.showCustomFields[key] ?? false;
                    // Defaulting to false for safety, or true if we want default share?
                    // Usually opt-in is safer for privacy.
                    return _buildToggle(
                      key,
                      isVisible,
                      (value) => _updateCustomFieldVisibility(type, key, value),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: GoogleFonts.inter())),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
