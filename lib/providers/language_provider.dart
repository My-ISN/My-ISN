import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('id'); // Default to Indonesian
  final _storage = const FlutterSecureStorage();

  Locale get locale => _locale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    String? languageCode = await _storage.read(key: 'language_code');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    _locale = Locale(languageCode);
    await _storage.write(key: 'language_code', value: languageCode);
    notifyListeners();
  }
}
