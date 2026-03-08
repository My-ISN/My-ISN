import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'services/notification_service.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'widgets/connectivity_wrapper.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'localization/app_localizations.dart';
import 'providers/language_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final languageProvider = LanguageProvider();
  // We don't wait for _loadSavedLanguage since it's called in constructor and notifyListeners will trigger rebuild

  try {
    await NotificationService().initialize(navigatorKey);
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
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
    debugPrint('Error reading stored user data: $e');
  }

  if (userData != null) {
    NotificationService().updateTokenOnServer(userData);
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => languageProvider,
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

    return MaterialApp(
      title: 'Foxgeen Mobile',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      supportedLocales: const [
        Locale('id', ''),
        Locale('en', ''),
      ],
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7E57C2)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return ConnectivityWrapper(child: child!);
      },
      home: initialUserData != null
          ? DashboardPage(userData: initialUserData!)
          : const LoginPage(),
    );
  }
}
