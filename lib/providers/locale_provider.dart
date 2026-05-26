import 'package:flutter/material.dart';

class _Prefs {
  static _Prefs? _instance;
  static Future<_Prefs> getInstance() async {
    _instance ??= _Prefs();
    return _instance!;
  }

  final Map<String, Object> _data = {};

  String? getString(String key) => _data[key] as String?;
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }
}

class LocaleProvider extends ChangeNotifier {
  static const _key = 'locale';

  Locale? _locale;

  Locale? get locale => _locale;

  String get localeName {
    switch (_locale?.languageCode) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
      default:
        return 'System';
    }
  }

  Future<void> load() async {
    final prefs = await _Prefs.getInstance();
    final code = prefs.getString(_key);
    _locale = code != null ? Locale(code) : null;
    notifyListeners();
  }

  Future<void> setLocale(String? code) async {
    _locale = code != null ? Locale(code) : null;
    notifyListeners();
    final prefs = await _Prefs.getInstance();
    if (code != null) {
      await prefs.setString(_key, code);
    } else {
      await prefs.remove(_key);
    }
  }
}

class LocaleScope extends InheritedNotifier<LocaleProvider> {
  const LocaleScope({
    super.key,
    required LocaleProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static LocaleProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
  }
}
