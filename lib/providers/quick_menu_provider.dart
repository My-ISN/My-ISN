import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class QuickMenuProvider extends ChangeNotifier {
  static const String _storageKey = 'custom_quick_menu_v1';
  final _storage = const FlutterSecureStorage();
  
  List<String>? _pinnedKeys;

  List<String>? get pinnedKeys => _pinnedKeys;

  QuickMenuProvider() {
    loadSavedSelection();
  }

  bool isPinned(String key) {
    return _pinnedKeys != null && _pinnedKeys!.contains(key);
  }

  void togglePin(String key) {
    if (_pinnedKeys == null) {
      _pinnedKeys = [key];
    } else {
      if (_pinnedKeys!.contains(key)) {
        _pinnedKeys!.remove(key);
      } else if (_pinnedKeys!.length < 5) {
        _pinnedKeys!.add(key);
      }
    }
    notifyListeners();
  }

  void setPinnedKeys(List<String>? keys) {
    _pinnedKeys = keys != null ? List.from(keys) : null;
    notifyListeners();
  }

  Future<void> save() async {
    if (_pinnedKeys == null) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: json.encode(_pinnedKeys));
    }
    notifyListeners();
  }

  Future<void> loadSavedSelection() async {
    try {
      String? saved = await _storage.read(key: _storageKey);
      if (saved != null) {
        final decoded = json.decode(saved);
        if (decoded is List) {
          _pinnedKeys = decoded.map((e) => e.toString()).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error loading pinned menus: $e');
    }
  }

  Future<void> clearCustomization() async {
    _pinnedKeys = null;
    await _storage.delete(key: _storageKey);
    notifyListeners();
  }
}
