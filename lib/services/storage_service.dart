import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting session data, login states, and account information using SharedPreferences.
class StorageService {
  /// Saves the provided [OdooSession] details to local storage.
  Future<void> saveSession(OdooSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', session.userName);
    await prefs.setString('userLogin', session.userLogin);
    await prefs.setString('userId', session.userId.toString());
    await prefs.setString("session_id", session.id);
    await prefs.setString("userName", session.userName);
    await prefs.setString("partnerId", session.partnerId.toString());
    await prefs.setString("userLang", session.userLang);
    await prefs.setString("userTz", session.userTz);
    await prefs.setBool("isSystem", session.isSystem);
    await prefs.setString("serverVersion", session.serverVersion);
    await prefs.setString("companyId", session.companyId.toString());
    await prefs.setString(
        "allowedCompanies", session.allowedCompanies.toString());
  }

  /// Saves the login state, database name, server URL, and password to persistent storage.
  Future<void> saveLoginState({
    required bool isLoggedIn,
    required String database,
    required String url,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('dbName', database);
    await prefs.setString('database', database);
    await prefs.setString('uri', url);
    await prefs.setString('password', password);
  }

  /// Retrieves the current login status and saved credentials.
  Future<Map<String, dynamic>> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
      'logoutAction': prefs.getBool('logoutAction') ?? false,
      'dbName': prefs.getString('dbName') ?? '',
      'uri': prefs.getString('uri') ?? '',
      'password': prefs.getString('password') ?? '',
    };
  }

  static const _accountsKey = 'loggedInAccounts';

  /// Saves or updates an account in the list of logged-in accounts.
  Future<void> saveAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();

    accounts.removeWhere((a) =>
        a['userId'] == account['userId'] &&
        a['uri'] == account['uri'] &&
        a['dbName'] == account['dbName']);

    accounts.add(account);

    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson == null) return [];
    final decoded = jsonDecode(accountsJson) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> clearAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
  }
}
