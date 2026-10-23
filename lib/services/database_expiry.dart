import 'storage_service.dart';
import '../Isarmodel/user_profile.dart';
import '../Isarmodel/Isar.dart';
import 'package:isar_community/isar.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Loginpage/login.dart';
import '../core/navigation/global_keys.dart';
import '../shared/widgets/snackbar.dart';

/// Thrown when the Odoo database a user is logging in to (or is already
/// logged in to) has passed its subscription expiration date.
class DatabaseExpiredException implements Exception {
  const DatabaseExpiredException();

  static const String message =
      'This database has expired. Please contact your administrator or '
      'Odoo to renew the subscription.';

  @override
  String toString() => 'Database Expired';
}

/// Detects expired Odoo databases and keeps them locked out.
///
/// Odoo itself still lets a user log in to an expired database - the web
/// client only shows a banner and blocks the UI from `session_info`'s
/// `expiration_date`. The mobile app has to enforce that itself, otherwise
/// the POS stays fully usable.
class DatabaseExpiry {
  static Future<bool> isExpired({
    required String serverUrl,
    required String sessionId,
  }) async {
    final raw = await _expirationDate(serverUrl, sessionId);
    if (raw == null || raw.isEmpty) return false;

    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2}):(\d{2}))?',
    ).firstMatch(raw.trim());
    if (match == null) return false;
    final parts = [
      for (var i = 1; i <= 6; i++) int.tryParse(match.group(i) ?? '') ?? 0,
    ];
    final expiry = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
    // Same rule as the Odoo web client: expired once the rounded number of
    // days left reaches zero.
    final daysLeft =
        expiry.difference(DateTime.now().toUtc()).inSeconds / 86400;
    return daysLeft.round() <= 0;
  }

  static Future<dynamic> _rpc(
    String url,
    String sessionId,
    String path,
    Map<String, dynamic> params,
  ) async {
    final response = await http
        .post(
          Uri.parse('$url$path'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Cookie': 'session_id=$sessionId',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'call',
            'params': params,
            'id': 1,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    return body is Map ? body['result'] : null;
  }

  static Future<String?> _expirationDate(
    String serverUrl,
    String sessionId,
  ) async {
    final url = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty || sessionId.isEmpty) return null;
    try {
      final info = await _rpc(url, sessionId, '/web/session/get_session_info', {});
      final value = info is Map ? info['expiration_date'] : null;
      if (value is String && value.isNotEmpty) return value;
    } catch (_) {}
    try {
      final value = await _rpc(url, sessionId, '/web/dataset/call_kw', {
        'model': 'ir.config_parameter',
        'method': 'get_param',
        'args': ['database.expiration_date'],
        'kwargs': {},
      });
      if (value is String && value.isNotEmpty) return value;
    } catch (_) {}
    return null;
  }

  /// Whether the database behind a *saved* account has expired. The saved
  /// session id is often stale, so sign in again with the stored credentials
  /// for a fresh session first. Unreachable servers / failed sign-ins count
  /// as "not expired" - only a confirmed expiry hides an account.
  static Future<bool> isAccountExpired({
    required String url,
    required String database,
    required String username,
    required String password,
    String sessionId = '',
  }) async {
    if (url.isEmpty) return false;
    if (await isMarkedExpired(url, database)) return true;
    // 1. The saved session - works for 2FA accounts, which can't sign in
    //    again with a password alone.
    if (sessionId.isNotEmpty) {
      try {
        if (await isExpired(serverUrl: url, sessionId: sessionId)) {
          await markExpired(url, database);
          return true;
        }
      } catch (_) {}
    }
    // 2. Fresh sign-in, for when the saved session has gone stale.
    if (database.isEmpty || username.isEmpty) return false;
    OdooClient? client;
    try {
      client = OdooClient(url);
      final session = await client
          .authenticate(database, username, password)
          .timeout(const Duration(seconds: 15));
      final expired = await isExpired(serverUrl: url, sessionId: session.id);
      if (expired) await markExpired(url, database);
      return expired;
    } catch (e) {
      debugPrint('DatabaseExpiry: could not check $username@$database: $e');
      return false;
    } finally {
      client?.close();
    }
  }

  static String _key(String url, String db) =>
      '${url.trim().replaceAll(RegExp(r'/+$'), '')}|$db';

  /// Remembers that [db] on [url] has expired (so every saved account on it
  /// can be hidden without signing in again) and removes those accounts from
  /// the saved-accounts stores.
  static Future<void> markExpired(String url, String db) async {
    if (url.isEmpty || db.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('expired_databases') ?? [];
    if (!list.contains(_key(url, db))) {
      list.add(_key(url, db));
      await prefs.setStringList('expired_databases', list);
    }
    await purgeSavedAccounts(url, db);
  }

  /// Forgets a previous expiry mark (the subscription was renewed).
  static Future<void> unmarkExpired(String url, String db) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('expired_databases') ?? [];
    if (list.remove(_key(url, db))) {
      await prefs.setStringList('expired_databases', list);
    }
  }

  static Future<bool> isMarkedExpired(String url, String db) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('expired_databases') ?? []).contains(
      _key(url, db),
    );
  }

  /// Deletes every saved account on [db] at [url] from all account stores.
  static Future<void> purgeSavedAccounts(String url, String db) async {
    final storage = StorageService();
    final prefs = await SharedPreferences.getInstance();
    final accounts = await storage.getAccounts();
    for (final a in accounts) {
      if (_key((a['uri'] ?? '').toString(), (a['dbName'] ?? '').toString()) !=
          _key(url, db)) {
        continue;
      }
      await storage.removeAccount(a);
      final login = (a['username'] ?? a['userLogin'] ?? '').toString();
      final login2 = (a['userLogin'] ?? '').toString();
      for (final name in {login, login2}) {
        final accountKey = '$name@$db';
        try {
          final isar = await IsarService.instance;
          await isar.writeTxn(() async {
            await isar.userProfiles
                .filter()
                .accountKeyEqualTo(accountKey)
                .deleteAll();
            await isar.signedAccounts
                .where()
                .accountIdentifierEqualTo(accountKey)
                .deleteAll();
            await isar.signedAccountListings
                .where()
                .accountIdentifierEqualTo(accountKey)
                .deleteAll();
          });
        } catch (_) {}
        final signed = prefs.getStringList('signed_accounts') ?? [];
        signed.remove(accountKey);
        await prefs.setStringList('signed_accounts', signed);
      }
    }
  }

  static bool _enforcing = false;

  /// If the stored session's database has expired, clears that session,
  /// returns to the login screen and says why. Returns true when it did.
  static Future<bool> enforceOnStoredSession() async {
    if (_enforcing) return false;
    _enforcing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id') ?? '';
      final url = prefs.getString('uri') ?? '';
      final database = prefs.getString('database') ?? prefs.getString('dbName') ?? '';
      if (sessionId.isEmpty || url.isEmpty) return false;
      if (!await isExpired(serverUrl: url, sessionId: sessionId)) return false;

      await markExpired(url, database);
      await clearStoredSession();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(serverUrl: url, database: database),
        ),
        (_) => false,
      );
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        CustomSnackbar.showError(context, DatabaseExpiredException.message);
      }
      return true;
    } finally {
      _enforcing = false;
    }
  }

  /// Drops the active login (keeps the server/database setup and the
  /// "get started" flag so the user lands on the login screen).
  static Future<void> clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      'session_id',
      'sessionId',
      'username',
      'password',
      'userId',
      'userLogin',
      'userName',
      'partnerId',
      'userLang',
      'userTz',
      'isSystem',
      'serverVersion',
      'companyId',
      'allowedCompanies',
      'pos_id',
      'signed_account',
    ]) {
      await prefs.remove(key);
    }
    await prefs.setBool('isLoggedIn', false);
  }
}

/// Re-checks the stored session whenever the app returns to the foreground.
class DatabaseExpiryObserver with WidgetsBindingObserver {
  DatabaseExpiryObserver._();
  static final DatabaseExpiryObserver instance = DatabaseExpiryObserver._();

  void start() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DatabaseExpiry.enforceOnStoredSession();
    }
  }
}
