import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:secbizcard/generated/l10n/app_localizations.dart';
import 'firebase_options.dart';
import 'core/config/theme.dart'; // 引入 Skill 1 產生的 Theme
import 'core/router/app_router.dart';
import 'core/config/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] WidgetsFlutterBinding initialized');
  
  // Adaptive orientation policy:
  //  - Phones (shortest side < 600dp): keep the portrait-only experience the
  //    app was designed around.
  //  - Tablets / iPads / unfolded foldables (>= 600dp): allow all orientations
  //    so large screens and Split View / Stage Manager work naturally.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSideDp =
      view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSideDp < 600) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  // Cap the in-memory image cache. This app mostly shows avatars and card
  // thumbnails, so Flutter's generous defaults (1000 images / 100 MB) are far
  // more than needed. Tightening this reduces peak memory — important on newer
  // Android memory limits and when multitasking on tablets/foldables.
  PaintingBinding.instance.imageCache
    ..maximumSize = 200
    ..maximumSizeBytes = 50 << 20; // 50 MB
  
  try {
    debugPrint('[Main] Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Main] Firebase initialized successfully');

    runApp(const ProviderScope(child: IxoApp()));
    debugPrint('[Main] runApp called');
  } catch (e, stack) {
    debugPrint('[Main] Firebase initialization failed: $e');
    debugPrint('[Main] Stack trace: $stack');
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
