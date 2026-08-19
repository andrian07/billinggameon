import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the logged-in session so it survives a page reload — Flutter web
/// rebuilds the whole app from scratch on a browser refresh, and without
/// this the user would always land back on the login page.
class SessionStorage {
  static const _key = "auth_session";

  // In-memory cache so the sidebar doesn't hit SharedPreferences on every
  // navigation; populated on first read and kept in sync by
  // setAllowedMenuKeys/clearSession. Null-vs-unloaded is tracked separately
  // because null is itself a valid value (meaning "unrestricted access").
  static Set<String>? _menuKeysCache;
  static bool _menuKeysCacheLoaded = false;
  static bool? _isSuperadminCache;

  Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }

  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// The set of sidebar `menuKey`s the logged-in user's role is allowed to
  /// view, derived from Access/role_access at login time. Null means
  /// unrestricted (superadmin, or the permission fetch failed and we fail
  /// open rather than hide the whole menu).
  Future<Set<String>?> getAllowedMenuKeys() async {
    if (_menuKeysCacheLoaded) return _menuKeysCache;

    final session = await getSession();
    final raw = session?['menuKeys'];
    _menuKeysCache = raw is List
        ? raw.map((e) => e.toString()).toSet()
        : null;
    _menuKeysCacheLoaded = true;
    return _menuKeysCache;
  }

  Future<void> setAllowedMenuKeys(Set<String>? keys) async {
    final session = await getSession() ?? <String, dynamic>{};
    session['menuKeys'] = keys?.toList();
    await saveSession(session);

    _menuKeysCache = keys;
    _menuKeysCacheLoaded = true;
  }

  /// Whether the logged-in user is the built-in superadmin (role id 1 — see
  /// AppUser.isSuperadmin). Used to gate menus that must never be exposed
  /// through the regular Access/role_access checkbox matrix.
  Future<bool> isSuperadmin() async {
    if (_isSuperadminCache != null) return _isSuperadminCache!;

    final session = await getSession();
    final role = session?['role'];
    final result = role == 1 || role?.toString() == '1';
    _isSuperadminCache = result;
    return result;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);

    _menuKeysCache = null;
    _menuKeysCacheLoaded = false;
    _isSuperadminCache = null;
  }
}
