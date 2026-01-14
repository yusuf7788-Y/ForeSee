import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';

import 'package:firebase_core/firebase_core.dart';

import 'models/user_profile.dart';
import 'screens/chat_screen.dart';
import 'services/theme_service.dart';
import 'services/storage_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        print("DotEnv Error: $e");
      }

      try {
        await Firebase.initializeApp();
      } catch (e) {
        print("Firebase Init Error: $e");
      }

      await themeService.loadTheme();
      runApp(const ForeSeeApp());
    },
    (error, stack) {
      print("Uncaught Error: $error");
      print(stack);
    },
  );
}

class ForeSeeApp extends StatefulWidget {
  const ForeSeeApp({super.key});

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
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initSystemThemeListener() {
    // Listen for system theme changes
    WidgetsBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      final newBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (_lastBrightness != newBrightness && themeService.themeIndex == 2) {
        _lastBrightness = newBrightness;
        // Force theme update when system theme changes and app is in system mode
        themeService.setThemeIndex(2, force: true);
      }
    };
    _lastBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
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
    if (uri.scheme == 'foresee' && uri.host == 'join') {
      final groupId = uri.queryParameters['groupId'];
      if (groupId != null) {
        // Delay slightly to ensure ChatScreen is mounted if app just started
        Future.delayed(const Duration(milliseconds: 1500), () {
          chatScreenKey.currentState?.joinGroupFromDeepLink(groupId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'ForeSee',
          debugShowCheckedModeBanner: false,
          theme: themeService.currentThemeData,
          home: const ChatScreen(),
        );
      },
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();
    return FutureBuilder<UserProfile?>(
      future: storage.loadUserProfile(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const ChatScreen();
      },
    );
  }
}
