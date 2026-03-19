import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secbizcard/generated/l10n/app_localizations.dart';

import '../../data/auth_repository.dart';
import '../../../profile/data/profile_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    await _handleSignIn(isGoogle: true);
  }

  Future<void> _handleAppleSignIn() async {
    await _handleSignIn(isGoogle: false);
  }

  Future<void> _handleSignIn({required bool isGoogle}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);

      debugPrint('[LoginScreen] Starting sign in, isGoogle=$isGoogle');

      final result = isGoogle
          ? await authRepo.signInWithGoogle(profileRepo)
          : await authRepo.signInWithApple(profileRepo);

      debugPrint('[LoginScreen] Sign in result: isRight=${result.isRight()}');

      if (!mounted) return;

      if (result.isLeft()) {
        final failure = result.getLeft().toNullable();
        debugPrint('[LoginScreen] Sign in failed: ${failure?.message}');
        if (failure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final user = result.getRight().toNullable();
        debugPrint('[LoginScreen] Sign in success, user=${user?.uid}');
        if (user != null && mounted) {
          final profileResult = await profileRepo.getUser(user.uid);

          debugPrint('[LoginScreen] Profile result: isRight=${profileResult.isRight()}');

          if (mounted) {
            profileResult.fold(
              (failure) {
                debugPrint('[LoginScreen] Profile fetch failed, going to /home');
                context.go('/home');
              },
              (profile) {
                if (profile.isOnboardingComplete) {
                  debugPrint('[LoginScreen] Onboarding complete, going to /home');
                  context.go('/home');
                } else {
                  debugPrint('[LoginScreen] Going to /onboarding');
                  context.go('/onboarding');
                }
              },
            );
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[LoginScreen] Unexpected error: $e');
      debugPrint('[LoginScreen] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bool isIOS = Platform.isIOS;

    // Determine primary/secondary based on platform
    final String primaryLabel =
        isIOS ? l10n.signInWithApple : l10n.signInWithGoogle;
    final VoidCallback primaryAction =
        isIOS ? _handleAppleSignIn : _handleGoogleSignIn;
    final IconData primaryIcon =
        isIOS ? FontAwesomeIcons.apple : FontAwesomeIcons.google;
    final Color primaryIconColor = isIOS ? Colors.white : Colors.red;
    final Color primaryBgColor = isIOS
        ? Colors.black
        : Theme.of(context).colorScheme.surface;
    final Color primaryFgColor = isIOS
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    final String secondaryProvider = isIOS ? 'Google' : 'Apple';
    final VoidCallback secondaryAction =
        isIOS ? _handleGoogleSignIn : _handleAppleSignIn;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo / Branding Area
              Column(
                children: [
                  SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.appTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginSlogan,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Primary Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : primaryAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: primaryBgColor,
                  foregroundColor: primaryFgColor,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isIOS
                          ? Colors.transparent
                          : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isIOS
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            primaryIcon,
                            size: 20,
                            color: primaryIconColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            primaryLabel,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              // Secondary Login Link
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : secondaryAction,
                  child: Text(
                    l10n.orSignInWith(secondaryProvider),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      decoration: TextDecoration.underline,
                      decorationColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
