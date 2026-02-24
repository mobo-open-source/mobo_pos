import 'package:local_auth/local_auth.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

/// Service providing authentication logic for Odoo and local biometrics.
class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Parses the major version number from an Odoo server version string.
  int parseMajorVersion(String? serverVersion) {
    if (serverVersion == null || serverVersion.isEmpty) return 0;

    final match = RegExp(r'(\d{1,2})').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Authenticates a user with Odoo and retrieves session details including system status.
  Future<OdooSession?> authenticateOdoo({
    required String url,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      final client = OdooClient(url);
      final session = await client.authenticate(database, username, password);

      if (session != null) {
        final userData = await client.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [session.userId],
            ['company_id'],
          ],
          'kwargs': {},
        });
        final int majorVersion = parseMajorVersion(session.serverVersion);
        bool isSystem = false;

        if (majorVersion >= 18) {
          isSystem = await client.callKw({
            'model': 'res.users',
            'method': 'has_group',
            'args': [session.userId, 'base.group_system'],
            'kwargs': {},
          });
        } else {
          isSystem = await client.callKw({
            'model': 'res.users',
            'method': 'has_group',
            'args': ['base.group_system'],
            'kwargs': {},
          });
        }

        return OdooSession(
          id: session.id,
          userId: session.userId,
          partnerId: session.partnerId,
          userLogin: session.userLogin,
          userName: session.userName,
          userLang: session.userLang,
          userTz: session.userTz,
          isSystem: isSystem,
          dbName: session.dbName,
          serverVersion: session.serverVersion,
          companyId: userData.isNotEmpty ? userData[0]['company_id'][0] : null,
          allowedCompanies: [],
        );
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
