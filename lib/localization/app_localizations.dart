import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, dynamic> _localizedStrings;

  Future<bool> load() async {
    final List<String> modules = [
      'main',
      'auth',
      'dashboard',
      'attendance',
      'announcement',
      'profile',
      'settings',
      'diagnosis',
      'payroll',
      'employees',
      'work_log',
      'rent_plan',
      'todo_list',
      'finance',
      'helpdesk',
    ];

    _localizedStrings = {};

    for (String module in modules) {
      try {
        String jsonString = await rootBundle.loadString(
          'assets/languages/${locale.languageCode}/$module.json',
        );
        Map<String, dynamic> jsonMap = json.decode(jsonString);
        _localizedStrings.addAll(jsonMap);
      } catch (e) {
        // ignore: avoid_print
        print('Error loading localization module $module: $e');
      }
    }
    return true;
  }

  String translate(String key, {Map<String, String>? args}) {
    List<String> keys = key.split('.');
    dynamic value = _localizedStrings;

    for (var k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return key;
      }
    }

    String result = value.toString();
    if (args != null) {
      args.forEach((key, value) {
        result = result.replaceAll('{$key}', value);
      });
    }
    return result;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'id'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension TranslateExtension on String {
  String tr(BuildContext context, {Map<String, String>? args}) {
    return AppLocalizations.of(context)?.translate(this, args: args) ?? this;
  }
}

extension RoleTranslateExtension on String {
  String roleTr(BuildContext context) {
    if (toLowerCase() == 'client role manage user') {
      return 'main.role_client'.tr(context);
    }
    return this;
  }
}
