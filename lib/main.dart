import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:ui';
import 'services/log_service.dart';
import 'services/notification_service.dart';
import 'services/tracking_service.dart';
import 'login_page.dart';
import 'dashboard/dashboard_page.dart';
import 'widgets/connectivity_wrapper.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'localization/app_localizations.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/quick_menu_provider.dart';
import 'providers/cart_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize Tracking Service
  try {
    await TrackingService().initialize();
  } catch (e) {
    Log.e('TrackingService initialization failed: $e');
  }

  // Setup Global Exception Handlers for App Health (Crash Tracking)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    TrackingService().logCrash(
      details.exceptionAsString(),
      details.stack?.toString() ?? 'No stack trace',
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    TrackingService().logCrash(error.toString(), stack.toString());
    return true;
  };

  final languageProvider = LanguageProvider();
  final themeProvider = ThemeProvider();
  final quickMenuProvider = QuickMenuProvider();

  try {
    await NotificationService().initialize(navigatorKey);
  } catch (e) {
    Log.e('Notification initialization failed: $e');
  }

  // Check login session
  const storage = FlutterSecureStorage();
  Map<String, dynamic>? userData;
  try {
    String? userDataString = await storage.read(key: 'user_data');
    if (userDataString != null) {
      userData = json.decode(userDataString);
    }
  } catch (e) {
    Log.e('Error reading stored user data: $e');
  }

  if (userData != null) {
    NotificationService().updateTokenOnServer(userData);
  }

  // Start tracking session (with user data if logged in, otherwise as guest)
  try {
    await TrackingService().startSession(userData);
  } catch (e) {
    Log.e('TrackingService session start failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => languageProvider),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => quickMenuProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MyApp(initialUserData: userData),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic>? initialUserData;
  const MyApp({super.key, this.initialUserData});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'My ISN Mobile',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      supportedLocales: const [Locale('id', ''), Locale('en', '')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7E57C2),
          primary: const Color(0xFF7E57C2),
          brightness: Brightness.light,
          surface: Colors.white,
          surfaceContainer: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerHighest: const Color(0xFFF1F5F9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        cardColor: Colors.white,
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7E57C2),
          primary: const Color(0xFF7E57C2),
          brightness: Brightness.dark,
          surface: const Color(0xFF000000),
          surfaceContainerHighest: const Color(0xFF000000),
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
      home: initialUserData != null
          ? DashboardPage(userData: initialUserData!)
          : const LoginPage(),
    );
  }
}
