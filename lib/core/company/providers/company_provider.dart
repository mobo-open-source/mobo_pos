import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';

/// State management provider for multi-company handling, mirroring the
/// company switcher in the Mobo CRM app but adapted to this app's
/// per-screen [OdooClient] pattern (there is no long-lived cached client /
/// session manager here — [AuthService.getAuthenticatedClient] rebuilds a
/// client from [SharedPreferences] on demand).
///
/// Responsibilities:
/// - Load & cache the user's available companies
/// - Manage the currently selected company (`company_id`)
/// - Manage the set of allowed companies (`allowed_company_ids`)
/// - Persist selection & allowed list across app restarts
/// - Switch the active company (via `res.users` write on the server)
class CompanyProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;
  List<int> _selectedAllowedCompanyIds = [];
  bool _loading = false;
  bool _switching = false;
  String? _error;

  List<Map<String, dynamic>> get companies => _companies;

  int? get selectedCompanyId => _selectedCompanyId;

  List<int> get selectedAllowedCompanyIds => _selectedAllowedCompanyIds;

  bool get isLoading => _loading;

  bool get isSwitching => _switching;

  String? get error => _error;

  /// Returns the full company map for the currently selected company, or null
  Map<String, dynamic>? get selectedCompany {
    if (_selectedCompanyId == null) return null;
    try {
      return _companies.firstWhere((c) => c['id'] == _selectedCompanyId);
    } catch (e) {
      return null;
    }
  }

  /// Builds a fresh authenticated [OdooClient] from the stored session,
  /// the same way [_checkPosInstallation] in the Shop screen does.
  Future<OdooClient?> _buildClient() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return null;

    final serverUrl = prefs.getString('uri');
    final dbName = prefs.getString('dbName');
    final userId = int.tryParse(prefs.getString('userId') ?? '');
    final password = prefs.getString('password');
    final sessionId = prefs.getString('session_id');
    final authLogin = prefs.getString('userLogin') ?? prefs.getString('username');

    if (serverUrl == null ||
        serverUrl.isEmpty ||
        dbName == null ||
        dbName.isEmpty ||
        userId == null ||
        password == null ||
        sessionId == null ||
        authLogin == null ||
        authLogin.isEmpty) {
      return null;
    }

    return AuthService().getAuthenticatedClient(
      url: serverUrl,
      database: dbName,
      username: authLogin,
      password: password,
      sessionId: sessionId,
      userId: userId,
      partnerId: int.tryParse(prefs.getString('partnerId') ?? '0') ?? 0,
      userLogin: prefs.getString('userLogin'),
      userName: prefs.getString('userName'),
      userLang: prefs.getString('userLang') ?? 'en_US',
      userTz: prefs.getString('userTz') ?? 'UTC',
      isSystem: prefs.getBool('isSystem') ?? false,
      serverVersion: prefs.getString('serverVersion') ?? '',
      companyId: int.tryParse(prefs.getString('companyId') ?? '1') ?? 1,
      twoFactorRequired: prefs.getBool('twoFactorRequired') ?? false,
    );
  }

  /// Update the list of allowed company IDs and persist it
  Future<void> setAllowedCompanies(List<int> allowedIds) async {
    final availableIds = _companies.map((c) => c['id'] as int).toSet();
    final filtered = allowedIds.where((id) => availableIds.contains(id)).toList();
    if (_selectedCompanyId != null && !filtered.contains(_selectedCompanyId)) {
      filtered.add(_selectedCompanyId!);
    }
    _selectedAllowedCompanyIds = filtered;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    notifyListeners();
  }

  /// Initializes provider state from preferences and the server.
  /// Should be called early (e.g. app start / after login).
  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final client = await _buildClient();
      final prefs = await SharedPreferences.getInstance();
      final userId = int.tryParse(prefs.getString('userId') ?? '');

      if (client == null || userId == null) {
        _companies = [];
        _selectedCompanyId = null;
        _loading = false;
        notifyListeners();
        return;
      }

      final userRes = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      List<int> companyIds = [];
      int? currentCompanyId;
      if (userRes is List && userRes.isNotEmpty) {
        final row = userRes.first as Map<String, dynamic>;
        if (row['company_ids'] is List) {
          companyIds = (row['company_ids'] as List).whereType<int>().toList();
        }
        if (row['company_id'] is List && (row['company_id'] as List).isNotEmpty) {
          currentCompanyId = (row['company_id'] as List).first as int?;
        }
      }

      if (companyIds.isEmpty) {
        _companies = [];
        _selectedCompanyId = currentCompanyId;
        _loading = false;
        notifyListeners();
        return;
      }

      final companiesRes = await client.callKw({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', companyIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name'],
          'order': 'name asc',
        },
      });

      _companies = (companiesRes is List)
          ? companiesRes.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      final restoredId = prefs.getInt('selected_company_id');
      final restoredAllowed = prefs
              .getStringList('selected_allowed_company_ids')
              ?.map((e) => int.tryParse(e) ?? -1)
              .where((e) => e > 0)
              .toList() ??
          [];

      int? desiredId = restoredId ?? currentCompanyId ?? companyIds.first;
      if (!companyIds.contains(desiredId)) {
        desiredId = companyIds.first;
      }
      _selectedCompanyId = desiredId;

      final restoredValid = restoredAllowed.where((id) => companyIds.contains(id)).toList();
      _selectedAllowedCompanyIds = restoredValid.isNotEmpty ? restoredValid : companyIds;
      if (_selectedCompanyId != null &&
          !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
        _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, _selectedCompanyId!];
      }

      await prefs.setInt('selected_company_id', _selectedCompanyId!);
      await prefs.setStringList(
        'selected_allowed_company_ids',
        _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
      );

      // Keep the app's existing `companyId` pref (read by the Shop screen /
      // AuthService client builder) in sync with the restored selection.
      if (currentCompanyId != desiredId) {
        try {
          await _applyCompanyOnServer(client, userId, desiredId);
        } catch (_) {}
      }
      await prefs.setString('companyId', _selectedCompanyId.toString());
    } catch (e) {
      if (_companies.isEmpty) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Reloads the list of available companies from the server
  Future<void> refreshCompaniesList() async {
    _loading = true;
    notifyListeners();
    try {
      final client = await _buildClient();
      final prefs = await SharedPreferences.getInstance();
      final userId = int.tryParse(prefs.getString('userId') ?? '');
      if (client != null && userId != null) {
        final userRes = await client.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [userId],
            ['company_ids'],
          ],
          'kwargs': {},
        });
        if (userRes is List && userRes.isNotEmpty) {
          final companyIds =
              ((userRes.first as Map<String, dynamic>)['company_ids'] as List?)
                      ?.cast<int>() ??
                  [];
          if (companyIds.isNotEmpty) {
            final companiesRes = await client.callKw({
              'model': 'res.company',
              'method': 'search_read',
              'args': [
                [
                  ['id', 'in', companyIds],
                ],
              ],
              'kwargs': {
                'fields': ['id', 'name'],
              },
            });
            if (companiesRes is List) {
              _companies = companiesRes.cast<Map<String, dynamic>>();
            }
          }
        }
      }
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Switches the active company — updates UI, prefs and the server.
  /// Returns `true` if the switch was successfully applied on the server.
  Future<bool> switchCompany(int companyId) async {
    if (_selectedCompanyId == companyId) return true;

    _switching = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_company_id', companyId);

    final allowed = {..._selectedAllowedCompanyIds, companyId}.toList();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      allowed.map((e) => e.toString()).toList(),
    );

    _selectedAllowedCompanyIds = allowed;
    _selectedCompanyId = companyId;
    notifyListeners();

    bool applied = false;
    try {
      final client = await _buildClient();
      final userId = int.tryParse(prefs.getString('userId') ?? '');
      if (client != null && userId != null) {
        await _applyCompanyOnServer(client, userId, companyId);
        // Keep the app's existing `companyId` pref in sync so every other
        // screen that rebuilds its own client (Shop, POS webview, ...)
        // picks up the new active company.
        await prefs.setString('companyId', companyId.toString());
        applied = true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _switching = false;
    notifyListeners();
    await refreshCompaniesList();
    return applied;
  }

  Future<void> _applyCompanyOnServer(OdooClient client, int userId, int companyId) async {
    final allowed =
        _selectedAllowedCompanyIds.isNotEmpty ? _selectedAllowedCompanyIds : [companyId];

    await client.callKw({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [userId],
        {'company_id': companyId},
      ],
      'kwargs': {
        'context': {'allowed_company_ids': allowed, 'company_id': companyId},
      },
    });
  }

  /// Toggle a company in/out of the allowed list (cannot remove current selection)
  Future<void> toggleAllowedCompany(int companyId) async {
    if (_selectedAllowedCompanyIds.contains(companyId)) {
      if (companyId == _selectedCompanyId) return;
      _selectedAllowedCompanyIds =
          _selectedAllowedCompanyIds.where((id) => id != companyId).toList();
    } else {
      _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    notifyListeners();
  }

  Future<void> selectAllCompanies() async {
    final allIds = _companies.map((c) => c['id'] as int).toList();
    await setAllowedCompanies(allIds);
  }

  Future<void> deselectAllCompanies() async {
    if (_selectedCompanyId != null) {
      await setAllowedCompanies([_selectedCompanyId!]);
    }
  }

  bool isCompanyAllowed(int companyId) {
    return _selectedAllowedCompanyIds.contains(companyId);
  }
}
