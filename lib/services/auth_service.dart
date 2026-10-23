import 'database_expiry.dart';
import 'package:isar_community/isar.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Isarmodel/Isar.dart';
import '../Isarmodel/user_profile.dart';
import 'storage_service.dart';

/// Thrown by [AuthService.getAuthenticatedClient] when the stored session for
/// a 2FA-enabled account is no longer valid. Unlike a regular account, a
/// plain `client.authenticate(db, login, password)` retry can never succeed
/// here — Odoo returns `{'uid': null}` instead of raising, which the
/// `odoo_rpc` package's session parser then crashes on trying to read
/// `user_context` off (`type 'Null' is not a subtype of type
/// 'Map<String, dynamic>'`). Callers must catch this and route the user back
/// through a fresh login (and TOTP challenge) instead of retrying.
class TwoFactorSessionExpiredException implements Exception {
  @override
  String toString() =>
      'Your two-factor authentication session has expired. Please log in again.';
}

/// Service providing authentication logic for Odoo and local biometrics.
class AuthService {
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

  /// Returns an [OdooClient] that's authenticated for the given account,
  /// reusing the stored session first and only falling back to a plain
  /// password [OdooClient.authenticate] when that session is stale.
  ///
  /// This must be used anywhere the app needs a fresh authenticated client
  /// for an already-logged-in account (checking installed modules, loading
  /// the profile picture, opening a POS session, ...) instead of calling
  /// `client.authenticate(db, login, password)` directly: for a 2FA-enabled
  /// account, that password-only call can never succeed — Odoo returns
  /// `{'uid': null}` rather than an error, which crashes deep inside
  /// `odoo_rpc`'s session parsing — and even for a non-2FA account it's an
  /// unnecessary re-authentication when the existing session still works.
  ///
  /// Throws [TwoFactorSessionExpiredException] when the stored session is
  /// stale and [twoFactorRequired] is true, since a password retry would
  /// crash rather than fail cleanly; the caller should route the user back
  /// through a fresh login instead of retrying.
  Future<OdooClient> getAuthenticatedClient({
    required String url,
    required String database,
    required String username,
    required String password,
    String? sessionId,
    int userId = 0,
    int partnerId = 0,
    String? userLogin,
    String? userName,
    String userLang = 'en_US',
    String userTz = 'UTC',
    bool isSystem = false,
    String serverVersion = '',
    int companyId = 1,
    bool twoFactorRequired = false,
  }) async {
    if (sessionId != null && sessionId.isNotEmpty) {
      // A freshly-established session (e.g. right after the TOTP webview
      // tears down and this client's first request races its network
      // stack) can fail once for reasons that have nothing to do with the
      // session itself. Retry a couple of times before concluding the
      // session is actually dead — for a 2FA account that conclusion means
      // forcing the user through a full TOTP challenge again, so it must
      // not be reached on a one-off transient blip.
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final probeSession = OdooSession(
            id: sessionId,
            userId: userId,
            partnerId: partnerId,
            userLogin:
                (userLogin != null && userLogin.isNotEmpty)
                    ? userLogin
                    : username,
            userName:
                (userName != null && userName.isNotEmpty) ? userName : username,
            userLang: userLang,
            userTz: userTz,
            isSystem: isSystem,
            dbName: database,
            serverVersion: serverVersion,
            companyId: companyId,
            allowedCompanies: const [],
          );
          final probeClient = OdooClient(url, sessionId: probeSession);
          await probeClient.callKw({
            'model': 'res.users',
            'method': 'search_read',
            'args': [
              [
                ['id', '=', userId],
              ],
            ],
            'kwargs': {
              'fields': ['id'],
              'limit': 1,
            },
          });
          return probeClient;
        } catch (e) {
          if (e is OdooException &&
              e.message.toLowerCase().contains('access')) {
            // A real permission error, not a dead session — surface it
            // immediately rather than masking it as "session expired".
            rethrow;
          }
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 600));
            continue;
          }
          // Stored session is genuinely stale — fall through below.
        }
      }
    }

    if (twoFactorRequired) {
      throw TwoFactorSessionExpiredException();
    }

    final client = OdooClient(url);
    await client.authenticate(database, username, password);
    return client;
  }

  /// The generic fallback message every login-error classifier in this app
  /// (`LoginPage._parseLoginError`, `SwitchAccountScreen._formatLoginError`)
  /// returns once none of its recognized error patterns (bad credentials,
  /// DNS/SSL/timeout, missing database, ...) match. Any login failure that
  /// still lands on this message is treated as "this account most likely has
  /// TOTP two-factor enabled" and routes to [TwoFactorAuthPage] instead of
  /// showing an error, matching mobo FullSuite's login flow.
  static const String genericLoginFailureMessage =
      'Login failed. Please check your credentials and try again.';

  /// Same fallback but as produced by [SwitchAccountScreen]'s own formatter.
  static const String genericSwitchAccountFailureMessage =
      'Login failed. Please check your credentials and server settings.';

  /// Maps a low-level login/authentication exception to a user-facing
  /// message, shared by [SwitchAccountScreen] and the profile page's account
  /// switcher. Any error that isn't recognized falls through to
  /// [genericSwitchAccountFailureMessage] — the signal used to assume the
  /// account has TOTP 2FA enabled and route to [TwoFactorAuthPage].
  static String formatLoginError(dynamic error) {
    if (error == null) return "Unknown error occurred";
    if (error is DatabaseExpiredException) return DatabaseExpiredException.message;
    final errorStr = error.toString().toLowerCase();

    // A Runbot test server can block API access to a given database from
    // the caller's network location (e.g. the shared "-all" database),
    // returning an error that has nothing to do with credentials or 2FA.
    // Recognize it explicitly so it isn't swallowed by the generic
    // fallback below and mistaken for "this account needs 2FA".
    if (errorStr.contains('runbot')) {
      return 'This Runbot database is not accessible from your current network location. Please use a development database or contact the Runbot team.';
    }

    if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database_manager_disabled')) {
      return 'Database listing is disabled (list_db=false). Cannot fetch databases automatically.';
    } else if (errorStr.contains('database') &&
        errorStr.contains('not found')) {
      return 'Selected database is not available. Please choose a different database.';
    } else if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. The server may be slow or unreachable.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Your account may not have permission to access this database.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL connection failed. Try using HTTP instead of HTTPS.';
    } else if (errorStr.contains('connection refused')) {
      return 'Server is not responding. Please verify the server URL and try again.';
    } else if (errorStr.contains('connection terminated during handshake')) {
      return 'Secure connection failed. The server may not support HTTPS or has an invalid SSL certificate. Try switching to HTTP or contact your administrator.';
    } else {
      return genericSwitchAccountFailureMessage;
    }
  }

  /// Persists a freshly authenticated session as the single "currently
  /// active" account, and upserts it into every account-listing store the
  /// app reads from — [StorageService]'s `loggedInAccounts` list plus the
  /// Isar `UserProfile`/`SignedAccount`/`SignedAccountListing` collections —
  /// all keyed consistently by `username@database`.
  ///
  /// This is the single save routine shared by direct login, add-account,
  /// switch-account, and the 2FA completion flow, so every entry point keeps
  /// the account stores in sync instead of each screen maintaining its own
  /// copy-pasted save logic.
  Future<void> saveAuthenticatedSession({
    required String url,
    required String database,
    required String username,
    required String password,
    required String sessionId,
    int? userId,
    String? userLogin,
    String? userName,
    int? partnerId,
    String? userLang,
    String? userTz,
    bool isSystem = false,
    String? serverVersion,
    int? companyId,
    bool twoFactorRequired = false,
    String imageBase64 = '',
  }) async {
    // Every login path (direct, add-account, switch-account, 2FA) ends here,
    // so refuse to persist a session for a database that has expired.
    if (await DatabaseExpiry.isExpired(serverUrl: url, sessionId: sessionId)) {
      await DatabaseExpiry.markExpired(url, database);
      throw const DatabaseExpiredException();
    }
    await DatabaseExpiry.unmarkExpired(url, database);
    final prefs = await SharedPreferences.getInstance();
    final resolvedUserLogin = userLogin ?? username;
    final resolvedUserName = userName ?? username;

    await prefs.setString('lastUrl', url);
    await prefs.setString('lastUsername', username);
    await prefs.setString('lastDatabase', database);
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('session_id', sessionId);
    await prefs.setString('uri', url);
    await prefs.setString('database', database);
    await prefs.setString('serverUrl', url);
    await prefs.setString('dbName', database);
    await prefs.setString('userId', (userId ?? 0).toString());
    await prefs.setString('sessionId', sessionId);
    await prefs.setString('username', username);
    await prefs.setString('userLogin', resolvedUserLogin);
    await prefs.setString('userName', resolvedUserName);
    await prefs.setString('password', password);
    await prefs.setString('partnerId', (partnerId ?? 0).toString());
    await prefs.setString('userLang', userLang ?? 'en_US');
    await prefs.setString('userTz', userTz ?? 'UTC');
    await prefs.setBool('isSystem', isSystem);
    await prefs.setString('serverVersion', serverVersion ?? '');
    await prefs.setString('companyId', (companyId ?? 1).toString());
    await prefs.setBool('logoutAction', false);
    await prefs.setBool('twoFactorRequired', twoFactorRequired);

    final storageService = StorageService();
    await storageService.saveAccount({
      'username': resolvedUserName,
      'userLogin': resolvedUserLogin,
      'userId': userId ?? 0,
      'sessionId': sessionId,
      'serverVersion': serverVersion ?? '',
      'userLang': userLang ?? 'en_US',
      'partnerId': partnerId ?? 0,
      'userTimezone': userTz ?? 'UTC',
      'companyId': companyId ?? 1,
      'isSystem': isSystem,
      'uri': url,
      'dbName': database,
      'password': password,
      'image': imageBase64,
      'lastLogin': DateTime.now().toIso8601String(),
    });

    final accountKey = '$username@$database';
    final isar = await IsarService.instance;

    final userProfile =
        UserProfile()
          ..userId = (userId ?? 0).toString()
          ..userName = resolvedUserName
          ..profileImageBase64 = imageBase64
          ..dbName = database
          ..serverUrl = url
          ..username = username
          ..password = password
          ..companyId = (companyId ?? 1).toString()
          ..accountKey = accountKey
          ..lastUpdated = DateTime.now();
    await isar.writeTxn(() async {
      final existing =
          await isar.userProfiles
              .filter()
              .accountKeyEqualTo(accountKey)
              .findFirst();
      if (existing != null) userProfile.id = existing.id;
      await isar.userProfiles.put(userProfile);
    });

    final signedAccount =
        SignedAccount()
          ..accountKey = accountKey
          ..username = username
          ..serverAddress = url
          ..database = database
          ..password = password
          ..userNameDisplay = resolvedUserName
          ..profileImage = imageBase64
          ..accountIdentifier = accountKey;
    await isar.writeTxn(() async {
      final existing =
          await isar.signedAccounts
              .where()
              .accountIdentifierEqualTo(accountKey)
              .findFirst();
      if (existing != null) signedAccount.id = existing.id;
      await isar.signedAccounts.put(signedAccount);
    });

    final signedAccountListing =
        SignedAccountListing()
          ..accountKey = accountKey
          ..username = username
          ..serverAddress = url
          ..database = database
          ..password = password
          ..userNameDisplay = resolvedUserName
          ..profileImage = imageBase64
          ..lastLoginTime = DateTime.now()
          ..accountIdentifier = accountKey;
    await isar.writeTxn(() async {
      final existing =
          await isar.signedAccountListings
              .where()
              .accountIdentifierEqualTo(accountKey)
              .findFirst();
      if (existing != null) signedAccountListing.id = existing.id;
      await isar.signedAccountListings.put(signedAccountListing);
    });

    final signedAccounts = prefs.getStringList('signed_accounts') ?? [];
    if (!signedAccounts.contains(accountKey)) {
      signedAccounts.add(accountKey);
      await prefs.setStringList('signed_accounts', signedAccounts);
    }
  }
}
