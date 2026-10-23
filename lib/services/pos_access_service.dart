import 'package:odoo_rpc/odoo_rpc.dart';

/// The result of checking an account's ability to use the POS module.
enum PosAccessStatus {
  /// The account can use the POS module; [PosAccessCheckResult.configs]
  /// carries the visible `pos.config` records.
  ok,

  /// The `point_of_sale` module isn't installed on this server.
  moduleNotInstalled,

  /// The account doesn't have read access to `pos.config` at all.
  accessDenied,

  /// The account has access, but no `pos.config` record is visible to it
  /// (e.g. none have "Show in POS Mobile" enabled).
  configMissing,
}

class PosAccessCheckResult {
  final PosAccessStatus status;
  final List<Map<String, dynamic>> configs;

  const PosAccessCheckResult(this.status, [this.configs = const []]);
}

/// Checks whether an authenticated [client]'s account can use the POS
/// module — shared between [BackendPage]'s post-login check and the
/// "Add Account" flow's pre-flight check, so an account that fails this
/// check is never treated as the active session in the first place.
class PosAccessService {
  PosAccessService._();

  static Future<PosAccessCheckResult> checkAccess(
    OdooClient client, {
    List<int>? allowedCompanyIds,
    bool showArchived = false,
  }) async {
    final modulesResponse = await client.callKw({
      'model': 'ir.module.module',
      'method': 'search_read',
      'args': [
        [
          ['name', '=', 'point_of_sale'],
          ['state', '=', 'installed'],
        ],
        ['name', 'state'],
      ],
      'kwargs': {},
    });

    if (modulesResponse.isEmpty) {
      return const PosAccessCheckResult(PosAccessStatus.moduleNotInstalled);
    }

    try {
      // Mirrors the Odoo backend's own company selector: a shop whose
      // company isn't in the currently allowed set shouldn't show up here,
      // the same way it drops out of the desktop web client's Shop list.
      final domain = <dynamic>[
        if (allowedCompanyIds != null && allowedCompanyIds.isNotEmpty)
          ['company_id', 'in', allowedCompanyIds],
        // Mirrors the backend's "Filters > Archived" option: by default
        // Odoo only returns active records, so an archived shop only shows
        // up once this filter is switched on.
        if (showArchived) ['active', '=', false],
      ];

      final configsResponse = await client.callKw({
        'model': 'pos.config',
        'method': 'search_read',
        'args': [
          domain,
          ['id', 'name', 'current_session_state', 'current_session_id', 'company_id'],
        ],
        'kwargs': {
          if (showArchived) 'context': {'active_test': false},
        },
      });

      if (configsResponse.isEmpty) {
        final hasUserFilter =
            showArchived || (allowedCompanyIds != null && allowedCompanyIds.isNotEmpty);

        // An empty result here doesn't necessarily mean this account has no
        // usable POS setup — it can just as easily mean the caller's own
        // Archived/Company filter matched nothing. Only the former is the
        // fatal "Configuration Required" case backend.dart logs the account
        // out for, so when a filter is active, confirm the account really
        // has zero visible configs (unfiltered) before reporting that.
        if (hasUserFilter) {
          final baseline = await client.callKw({
            'model': 'pos.config',
            'method': 'search_read',
            'args': [
              [],
              ['id'],
            ],
            'kwargs': {},
          });
          if (baseline is List && baseline.isNotEmpty) {
            return const PosAccessCheckResult(PosAccessStatus.ok, []);
          }
        }

        return const PosAccessCheckResult(PosAccessStatus.configMissing);
      }

      return PosAccessCheckResult(
        PosAccessStatus.ok,
        List<Map<String, dynamic>>.from(configsResponse),
      );
    } catch (e) {
      if (e.toString().contains('AccessError') ||
          e.toString().contains('not allowed to access')) {
        return const PosAccessCheckResult(PosAccessStatus.accessDenied);
      }
      rethrow;
    }
  }
}
