import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Service backing the Settings page's Language & Region section: fetches
/// the server's available languages/currencies/timezones and updates the
/// current user's language/timezone.
class SettingService {
  OdooClient? client;
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes the Odoo client for the current account, reusing its
  /// stored session first and only falling back to password auth when
  /// that's stale (see [AuthService.getAuthenticatedClient] — a plain
  /// password retry can never succeed for a 2FA-enabled account and
  /// crashes rather than fails cleanly, so it must not be attempted
  /// unconditionally here).
  Future<void> initializeClient() async {
    final prefs = await SharedPreferences.getInstance();
    url = prefs.getString('uri') ?? '';
    final sessionId = prefs.getString('session_id') ?? '';
    final dbName = prefs.getString('dbName') ?? '';
    final userIdStr = prefs.getString('userId') ?? '0';
    final partnerIdStr = prefs.getString('partnerId') ?? '0';
    final companyIdStr = prefs.getString('companyId') ?? '0';

    if (url.isEmpty || sessionId.isEmpty) return;

    final username = prefs.getString('username') ?? '';
    final password = prefs.getString('password') ?? '';
    final authLogin = prefs.getString('userLogin') ?? username;

    userId = int.tryParse(userIdStr);
    companyId = int.tryParse(companyIdStr);

    client = await AuthService().getAuthenticatedClient(
      url: url,
      database: dbName,
      username: authLogin,
      password: password,
      sessionId: sessionId,
      userId: int.tryParse(userIdStr) ?? 0,
      partnerId: int.tryParse(partnerIdStr) ?? 0,
      userLogin: prefs.getString('userLogin'),
      userName: prefs.getString('userName'),
      userLang: prefs.getString('userLang') ?? 'en_US',
      userTz: prefs.getString('userTz') ?? 'UTC',
      isSystem: prefs.getBool('isSystem') ?? false,
      serverVersion: prefs.getString('serverVersion') ?? '',
      companyId: int.tryParse(companyIdStr) ?? 1,
      twoFactorRequired: prefs.getBool('twoFactorRequired') ?? false,
    );
  }

  /// Fetches the server's active languages.
  Future<List<dynamic>?> fetchLanguage() async {
    try {
      final languageDetails = await client?.callKw({
        'model': 'res.lang',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['code', 'name', 'iso_code', 'direction'],
          'order': 'name',
        },
      });
      return languageDetails?.isNotEmpty == true ? languageDetails : null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the server's active currencies.
  Future<List<dynamic>?> fetchCurrency() async {
    try {
      final currencyDetails = await client?.callKw({
        'model': 'res.currency',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
          ['name', 'full_name', 'symbol', 'position', 'rounding'],
        ],
        'kwargs': {'order': 'name'},
      });
      return currencyDetails?.isNotEmpty == true ? currencyDetails : null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the timezone options from `res.users`' `tz` field selection.
  Future<List<Map<String, dynamic>>> fetchTimezones() async {
    const fallbackTimezones = [
      {'code': 'UTC', 'name': 'UTC'},
      {'code': 'America/New_York', 'name': 'Eastern Time (US & Canada)'},
      {'code': 'America/Chicago', 'name': 'Central Time (US & Canada)'},
      {'code': 'America/Denver', 'name': 'Mountain Time (US & Canada)'},
      {'code': 'America/Los_Angeles', 'name': 'Pacific Time (US & Canada)'},
      {'code': 'Europe/London', 'name': 'London'},
      {'code': 'Europe/Paris', 'name': 'Paris'},
      {'code': 'Europe/Berlin', 'name': 'Berlin'},
      {'code': 'Asia/Tokyo', 'name': 'Tokyo'},
      {'code': 'Asia/Shanghai', 'name': 'Shanghai'},
      {'code': 'Asia/Kolkata', 'name': 'Mumbai, Kolkata, New Delhi'},
      {'code': 'Asia/Dubai', 'name': 'Dubai'},
      {'code': 'Australia/Sydney', 'name': 'Sydney'},
    ];

    try {
      final result = await client?.callKw({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [
          ['tz'],
        ],
        'kwargs': {
          'attributes': ['selection', 'string'],
        },
      });

      final tzField = result != null ? result['tz'] as Map<String, dynamic>? : null;
      final selection = tzField != null ? tzField['selection'] as List<dynamic>? : null;

      if (selection == null || selection.isEmpty) return fallbackTimezones;

      return selection.map<Map<String, dynamic>>((item) {
        if (item is List && item.length >= 2) {
          return {'code': item[0].toString(), 'name': item[1].toString()};
        }
        return {'code': item.toString(), 'name': item.toString()};
      }).toList();
    } catch (e) {
      return fallbackTimezones;
    }
  }

  /// Updates the current user's language and/or timezone.
  Future<bool> updateLanguage(int id, Map<String, dynamic> updatedValue) async {
    try {
      final result = await client?.callKw({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [id],
          updatedValue,
        ],
        'kwargs': {},
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
