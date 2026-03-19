import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
