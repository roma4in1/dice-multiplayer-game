import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('localStorage')
external _LocalStorage get _ls;

extension type _LocalStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

/// Persists the player's chosen display name across sessions via localStorage.
class NameService {
  NameService._();

  static const _key = 'dice_player_name';

  static String? get savedName {
    if (!kIsWeb) return null;
    try {
      final v = _ls.getItem(_key);
      return (v != null && v.isNotEmpty) ? v : null;
    } catch (_) {
      return null;
    }
  }

  static void save(String name) {
    if (!kIsWeb || name.trim().isEmpty) return;
    try {
      _ls.setItem(_key, name.trim());
    } catch (_) {}
  }
}
