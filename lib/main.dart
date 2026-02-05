import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:firebase_core/firebase_core.dart';

import 'models/user_profile.dart';
import 'screens/chat_screen.dart';
import 'screens/first_run_name_screen.dart';
import 'services/theme_service.dart';
import 'services/storage_service.dart';
import 'services/openrouter_service.dart';
import 'services/home_widget_service.dart';
import 'services/fcm_service.dart';
import 'utils/globals.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      bool envLoaded = true;
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        print("DotEnv Error: $e");
        envLoaded = false;
      }

      try {
        await Firebase.initializeApp();
        // FCM başlat (admin push bildirimleri için)
        await FCMService().initialize();
      } catch (e) {
        print("Firebase Init Error: $e");
      }

      await themeService.loadTheme();
      OpenRouterService.initKeys(); // Load and obfuscate keys

      // Açılış hızını artırmak için profili burada yükle
      final userProfile = await StorageService().loadUserProfile();

      runApp(
        RestartWidget(
          key: RestartWidget._restartKey,
          child: ForeSeeApp(envLoaded: envLoaded, profile: userProfile),
        ),
      );
    },
    (error, stack) {
      print("Uncaught Error: $error");
      print(stack);
    },
  );
}

class ForeSeeApp extends StatefulWidget {
  final bool envLoaded;
  final UserProfile? profile;
  const ForeSeeApp({super.key, this.envLoaded = true, this.profile});

  @override
  State<ForeSeeApp> createState() => _ForeSeeAppState();
}

class _ForeSeeAppState extends State<ForeSeeApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Brightness? _lastBrightness;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initSystemThemeListener();
    _initQuickActions();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initSystemThemeListener() {
    // Listen for system theme changes
    WidgetsBinding
        .instance
        .platformDispatcher
        .onPlatformBrightnessChanged = () {
      final newBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (_lastBrightness != newBrightness && themeService.themeIndex == 2) {
        _lastBrightness = newBrightness;
        // Force theme update when system theme changes and app is in system mode
        themeService.setThemeIndex(2, force: true);
      }
    };
    _lastBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  void _initQuickActions() {
    const QuickActions quickActions = QuickActions();
    quickActions.setShortcutItems([
      ShortcutItem(
        type: 'camera',
        localizedTitle: 'Kamerayla sor',
        icon: 'camera_quick',
      ),
      ShortcutItem(
        type: 'input',
        localizedTitle: 'ForeSee\'e birşey sor',
        icon: 'input_quick',
      ),
      ShortcutItem(
        type: 'health',
        localizedTitle: 'Dur, Silme, bir şans daha tanı bana',
        icon: 'health_quick',
      ),
    ]);
    quickActions.initialize((type) {
      if (type == 'camera') {
        // Open camera mode
        Future.delayed(const Duration(milliseconds: 500), () {
          (chatScreenKey.currentState as dynamic)?.openCameraFromQuickAction();
        });
      } else if (type == 'input') {
        // Focus on input
        Future.delayed(const Duration(milliseconds: 500), () {
          (chatScreenKey.currentState as dynamic)?.focusInputFromQuickAction();
        });
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check initial link (app opened via link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });

    // Handle incoming links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Incoming Deep Link: $uri');
    if (uri.scheme != 'foresee') return;

    if (uri.host == 'join') {
      final groupId = uri.queryParameters['groupId'];
      if (groupId != null) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          (chatScreenKey.currentState as dynamic)?.joinGroupFromDeepLink(
            groupId,
          );
        });
      }
    } else if (uri.host == 'chat') {
      final chatId = uri.queryParameters['id'];
      if (chatId != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          (chatScreenKey.currentState as dynamic)?.openChatFromDeepLink(chatId);
        });
      }
    } else if (uri.host == 'quick-ai') {
      final action = uri.queryParameters['action'] ?? 'input';
      Future.delayed(const Duration(milliseconds: 1000), () {
        (chatScreenKey.currentState as dynamic)?.handleQuickAiAction(action);
      });
    } else if (uri.host == 'settings') {
      Future.delayed(const Duration(milliseconds: 1000), () {
        (chatScreenKey.currentState as dynamic)?.openStatsFromDeepLink();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.envLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'Kritik Başlatma Hatası',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '.env yapılandırma dosyası yüklenemedi.\nLütfen "assets/.env" dosyasının mevcut olduğundan emin olun.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'ForeSee',
          debugShowCheckedModeBanner: false,
          theme: themeService.currentThemeData,
          home: _AppRouter(profile: widget.profile),
        );
      },
    );
  }
}

class _AppRouter extends StatelessWidget {
  final UserProfile? profile;
  const _AppRouter({this.profile});

  @override
  Widget build(BuildContext context) {
    debugPrint('DEBUG: Profile in router: ${profile?.username}');
    if (profile == null ||
        profile!.username == null ||
        profile!.username!.isEmpty) {
      return const FirstRunNameScreen();
    }

    return ChatScreen();
  }
}

class RestartWidget extends StatefulWidget {
  final Widget child;
  static final GlobalKey<_RestartWidgetState> _restartKey =
      GlobalKey<_RestartWidgetState>();

  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    if (_restartKey.currentState != null) {
      _restartKey.currentState!.restartApp();
    } else {
      // Fallback to context search if key is not attached for some reason
      context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
    }
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: key, child: widget.child);
  }
}
