import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fire_auth;
import 'package:secbizcard/features/auth/data/auth_repository.dart';
import 'package:secbizcard/features/auth/presentation/screens/login_screen.dart';
import 'package:secbizcard/features/handshake/presentation/screens/handshake_screen.dart';
import 'package:secbizcard/features/handshake/presentation/screens/qr_display_screen.dart';
import 'package:secbizcard/features/handshake/presentation/screens/qr_scanner_screen.dart';
import 'package:secbizcard/features/handshake/presentation/screens/handshake_history_screen.dart';
import 'package:secbizcard/features/home/presentation/screens/main_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/edit_contact_screen.dart';
import 'package:secbizcard/features/settings/presentation/screens/backup_screen.dart';
import 'package:secbizcard/features/profile/domain/user_profile.dart';
import 'package:secbizcard/features/profile/presentation/screens/context_settings_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/contact_detail_screen.dart';
import 'package:secbizcard/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:secbizcard/features/profile/presentation/screens/profile_screen.dart';
import 'package:secbizcard/features/landing/presentation/landing_screen.dart';
import 'package:secbizcard/features/landing/presentation/splash_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/scan_card_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/contact_review_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/manual_crop_screen.dart';
import 'package:secbizcard/features/contacts/presentation/screens/contacts_list_screen.dart';

part 'app_router.g.dart';

// keepAlive: true is critical — prevents the router from being
// disposed and re-created during widget rebuilds, which would
// briefly emit AsyncLoading and flash the login screen.
@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final authNotifier = ValueNotifier<AsyncValue<fire_auth.User?>>(
    ref.read(authStateProvider),
  );

  ref.listen(authStateProvider, (_, next) => authNotifier.value = next);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = authNotifier.value;
      final user = authState.valueOrNull;
      final matchedLocation = state.matchedLocation;
      final loggingIn = matchedLocation == '/login';
      const isWeb = kIsWeb;

      // When loading OR error: do not redirect — stay on current page.
      // This prevents a transient null (during Firebase Auth init or app
      // resume) from flashing the login screen.
      if (authState.isLoading || authState.hasError) return null;

      // WEB: Landing page '/' is public
      if (isWeb && matchedLocation == '/') return null;

      // Not logged in -> force login (except for public paths)
      if (user == null) {
        // Allow handshake paths for web (they'll see invitation)
        if (isWeb && matchedLocation.startsWith('/handshake/')) return null;
        if (loggingIn) return null;
        return '/login';
      }

      // Logged in -> redirect based on location
      if (loggingIn || matchedLocation == '/') {
        return '/home';
      }

      return null;
    },
    routes: [
      // Root route: SplashScreen on mobile, LandingScreen on web
      GoRoute(
        path: '/',
        builder: (context, state) {
          if (kIsWeb) return const LandingScreen();
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final initialTab = int.tryParse(tabStr ?? '') ?? 0;
          return MainScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/contacts',
        builder: (context, state) => const ContactsListScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) {
          final user = state.extra as UserProfile;
          return EditProfileScreen(user: user);
        },
      ),
      GoRoute(
        path: '/contact-detail',
        builder: (context, state) {
          final user = state.extra as UserProfile;
          return ContactDetailScreen(user: user);
        },
      ),
      GoRoute(
        path: '/edit-contact',
        builder: (context, state) {
          final user = state.extra as UserProfile;
          return EditContactScreen(user: user);
        },
      ),
      GoRoute(
        path: '/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/handshake/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return HandshakeScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/qr-display',
        builder: (context, state) => const QrDisplayScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/context-settings',
        builder: (context, state) {
          final user = state.extra as UserProfile;
          return ContextSettingsScreen(user: user);
        },
      ),
      GoRoute(
        path: '/handshake-history',
        builder: (context, state) => const HandshakeHistoryScreen(),
      ),

      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanCardScreen(),
      ),
      GoRoute(
        path: '/manual-crop',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>;
          return ManualCropScreen(
            imagePath: extras['imagePath'],
            initialPoints: extras['initialPoints'],
            imageWidth: extras['imageWidth'],
            imageHeight: extras['imageHeight'],
            isVertical: extras['isVertical'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/review-contact',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return ContactReviewScreen(
            profile: args['profile'] as UserProfile,
            imagePath: args['imagePath'] as String,
          );
        },
      ),

      // Wildcard for short URLs (ixo.app/abc123 on both web and mobile)
      GoRoute(
        path: '/:sessionId',
        redirect: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          const reserved = [
            'home',
            'login',
            'profile',
            'backup',
            'privacy',
            'eula',
          ];

          // Check if it's a valid session ID (6 chars alphanumeric)
          final isValidSession =
              sessionId.length == 6 &&
              RegExp(r'^[a-zA-Z0-9]+$').hasMatch(sessionId) &&
              !reserved.contains(sessionId);

          if (!isValidSession) {
            // Invalid session - redirect based on auth
            final user = ref.read(authStateProvider).valueOrNull;
            return user == null ? '/login' : '/home';
          }

          // Valid session - on mobile, redirect to /handshake/:sessionId
          if (!kIsWeb) {
            return '/handshake/$sessionId';
          }

          return null; // Allow on web (will render HandshakeScreen below)
        },
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return HandshakeScreen(sessionId: sessionId);
        },
      ),
    ],
  );
}
