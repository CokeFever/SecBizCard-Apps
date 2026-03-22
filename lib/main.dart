import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'core/config/theme.dart'; // 引入 Skill 1 產生的 Theme
import 'core/router/app_router.dart';
import 'core/config/theme_controller.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 靜默喚醒 Google 登入狀態 (輔助 Android Firebase 維持 Session)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await GoogleSignIn(
          // The Web client ID from Firebase console (client_type: 3 in google-services.json)
          serverClientId: '769422548283-rvuciu2cmfj9149fudj9q59pql4ofo8q.apps.googleusercontent.com',
        ).signInSilently();
      } catch (e) {
        debugPrint('Google signInSilently error: $e');
      }
    }

    // 記得這裡要包覆 ProviderScope
    runApp(const ProviderScope(child: IxoApp()));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Initialization Error: $e'))),
      ),
    );
  }
}

class IxoApp extends ConsumerWidget {
  const IxoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the Notification Service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initialize();
    });

    final router = ref.watch(goRouterProvider);
    final themeMode =
        ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.system;

    return MaterialApp.router(
      title: 'SecBizCard',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // 設定主題 (來自 core/config/theme.dart)
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // 設定路由 (來自 core/router/app_router.dart)
      routerConfig: router,

      // 開發時可關閉右上角的 debug 標籤
      debugShowCheckedModeBanner: false,
    );
  }
}
