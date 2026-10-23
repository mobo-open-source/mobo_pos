import '../services/database_expiry.dart';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:isar_community/isar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_pos/Isarmodel/user_profile.dart';
import 'package:mobo_pos/odoo_webapp/backend.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../Isarmodel/Isar.dart';
import 'profile.dart';
import '../Loginpage/server_setup_screen.dart';
import '../Loginpage/two_factor_authentication.dart';
import '../core/two_factor_auth.dart';
import '../services/review_service.dart';
import '../core/image_utils.dart';
import '../core/utils/odoo_url.dart';

class WebViewApp extends StatefulWidget {
  const WebViewApp({Key? key}) : super(key: key);

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

// Odoo's POS "Switch to Dark/Light Mode" (pos_enterprise navbar) only does
// `document.cookie = "pos_color_scheme=dark; path=/; max-age=..."` followed by
// `location.reload()`; the *server* then picks the dark or light asset bundle
// from that request cookie (point_of_sale/views/pos_assets_index.xml). Inside
// the WebView that JS-written cookie is not reliably committed to the native
// cookie jar before the immediate reload, so the reload goes out without it
// and the server renders the previous theme again. This hook mirrors the
// cookie into the native CookieManager (awaited on the Flutter side) and then
// reloads, so the next request is guaranteed to carry it.
const String _colorSchemeCookieHookJs = """
(function() {
  if (window.__moboColorSchemeHook) return;
  window.__moboColorSchemeHook = true;
  var desc = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie');
  if (!desc || !desc.configurable) return;
  Object.defineProperty(document, 'cookie', {
    configurable: true,
    get: function() { return desc.get.call(document); },
    set: function(value) {
      desc.set.call(document, value);
      try {
        var m = /^\\s*pos_color_scheme=([^;]*)/.exec(String(value));
        if (m && window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('moboColorScheme', m[1]);
        }
      } catch (e) {}
    }
  });
})();
""";


// Newer Odoo POS bundles use the ES2024 Set methods (difference/union/
// intersection/...) to diff IndexedDB tables for their offline order/product
// cache. Android's System WebView only gained these (via its underlying
// Chromium) in version 122 (early 2024) - on any device still on an older
// WebView, calling e.g. `set.difference(...)` throws
// "TypeError: ... .difference is not a function" deep inside that IndexedDB
// step, which Odoo's error service catches but cannot recover from, leaving
// the POS's own boot sequence stuck on its "Loading" screen forever (this
// WebView's onLoadStop still fires fine, since the page itself did load -
// it's the app's internal data-loading step that never completes). Injected
// at document-start so it's defined before that code runs, and only adds
// methods that are actually missing so a WebView that already has them is
// untouched.
const String _setMethodsPolyfillJs = """
(function() {
  if (typeof Set === 'undefined' || typeof Set.prototype.difference === 'function') return;
  function toSet(other) { return other instanceof Set ? other : new Set(other); }
  Set.prototype.union = function(other) {
    var result = new Set(this);
    toSet(other).forEach(function(v) { result.add(v); });
    return result;
  };
  Set.prototype.intersection = function(other) {
    var o = toSet(other), result = new Set();
    this.forEach(function(v) { if (o.has(v)) result.add(v); });
    return result;
  };
  Set.prototype.difference = function(other) {
    var result = new Set(this);
    toSet(other).forEach(function(v) { result.delete(v); });
    return result;
  };
  Set.prototype.symmetricDifference = function(other) {
    var result = new Set(this);
    toSet(other).forEach(function(v) {
      if (result.has(v)) result.delete(v); else result.add(v);
    });
    return result;
  };
  Set.prototype.isSubsetOf = function(other) {
    var o = toSet(other), ok = true;
    this.forEach(function(v) { if (!o.has(v)) ok = false; });
    return ok;
  };
  Set.prototype.isSupersetOf = function(other) {
    var self = this, ok = true;
    toSet(other).forEach(function(v) { if (!self.has(v)) ok = false; });
    return ok;
  };
  Set.prototype.isDisjointFrom = function(other) {
    var o = toSet(other), ok = true;
    this.forEach(function(v) { if (o.has(v)) ok = false; });
    return ok;
  };
})();
""";

class _WebViewAppState extends State<WebViewApp> {
  final GlobalKey webViewKey = GlobalKey();
  late String sessionID = '';
  late var currentUrl;
  String Domain = '';
  late CookieManager cookieManager;
  late String posUrl;
  String? downloadid;
  String? model;
  var serverUrl;
  String? filename;
  String? profilePictureBase64;
  Uint8List? profilePictureBytes;
  InAppWebViewController? webViewController;
  final ReceivePort _port = ReceivePort();
  bool isInitialLoad = true;
  bool _retriedFirstLoad = false;
  bool isLoading = true;
  bool showBarcodeScanner = false;
  bool _isLoggingOut = false;
  double loadingProgress = 0.0;
  String? dbName;
  bool _isLoadingProfilePicture = false;
  // Safety net for the loading overlay: onLoadStart/onLoadStop are expected
  // to pair up, but a WebView navigation event that starts a load without a
  // matching "finished" callback (e.g. a client-side redirect the WebView
  // coalesces oddly) would otherwise leave isLoading stuck true forever,
  // hiding an already-working POS page behind the spinner indefinitely.
  Timer? _loadingSafetyTimer;

  void _armLoadingSafetyTimer() {
    _loadingSafetyTimer?.cancel();
    _loadingSafetyTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && isLoading) {
        setState(() => isLoading = false);
      }
    });
  }

  void _disarmLoadingSafetyTimer() {
    _loadingSafetyTimer?.cancel();
    _loadingSafetyTimer = null;
  }

  Future<void> fetchProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var serverUrl = prefs.getString("uri");
      var sessionId = prefs.getString("session_id");
      var partnerId = prefs.getString("partnerId");
      var dbName = prefs.getString("dbName");
      var username = prefs.getString("username");
      var userLogin = prefs.getString("userLogin");
      var password = prefs.getString("password");

      var authLogin = userLogin ?? username;

      if (serverUrl == null ||
          sessionId == null ||
          partnerId == null ||
          dbName == null ||
          username == null ||
          password == null) {
        return;
      }

      final session = OdooSession(
        id: sessionId,
        userId: int.parse(prefs.getString("userId") ?? "0"),
        partnerId: int.parse(partnerId),
        userLogin: prefs.getString("userLogin") ?? "",
        userName: prefs.getString("userName") ?? "",
        userLang: prefs.getString("userLang") ?? "",
        userTz: prefs.getString("userTz") ?? "",
        isSystem: prefs.getBool("isSystem") ?? false,
        dbName: dbName,
        serverVersion: prefs.getString("serverVersion") ?? "",
        companyId: int.parse(prefs.getString("companyId") ?? "0"),
        allowedCompanies: [],
      );

      var client = OdooClient(serverUrl);

      // CRITICAL: Re-authenticate the client
      if (authLogin == null) return;
      await client.authenticate(dbName, authLogin, password);

      final response = await client.callKw({
        'model': 'res.partner',
        'method': 'read',
        'args': [
          [int.parse(partnerId)],
          ['image_1920'],
        ],
        'kwargs': {},
      });

      if (response.isNotEmpty) {
        final imageData = ImageUtils.base64Of(response[0]['image_1920']);
        if (imageData.isNotEmpty && mounted) {
          final bytes = base64Decode(imageData);
          if (ImageUtils.isValidImage(bytes)) {
            setState(() {
              profilePictureBase64 = imageData;
              profilePictureBytes = bytes;
            });
          } else {}
        }
      }

      client.close();
    } catch (e) {
      if (mounted) {}
    }
  }

  Future<void> _loadProfilePicture() async {
    // Prevent multiple simultaneous loads
    if (_isLoadingProfilePicture || !mounted) return;
    _isLoadingProfilePicture = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString("uri");
      final dbName = prefs.getString("dbName");
      final username = prefs.getString("username");

      if (serverUrl == null || dbName == null || username == null || !mounted) {
        _isLoadingProfilePicture = false;
        return;
      }

      final sessionId = prefs.getString('session_id');
      final userIdInt = int.tryParse(prefs.getString('userId') ?? '0');
      final partnerIdInt = int.tryParse(prefs.getString('partnerId') ?? '0');
      final companyIdStored = int.tryParse(prefs.getString('companyId') ?? '0');

      if (sessionId == null || userIdInt == null || companyIdStored == null)
        return;

      final session = OdooSession(
        id: sessionId,
        userId: userIdInt,
        partnerId: partnerIdInt ?? 0,
        userLogin: prefs.getString('userLogin') ?? username,
        userName: prefs.getString('userName') ?? '',
        userLang: prefs.getString('userLang') ?? 'en_US',
        userTz: prefs.getString('userTz') ?? 'UTC',
        isSystem: prefs.getBool('isSystem') ?? false,
        dbName: dbName,
        serverVersion: prefs.getString('serverVersion') ?? '',
        companyId: companyIdStored,
        allowedCompanies: [],
      );

      // Reuse the already-active session instead of re-authenticating with
      // the stored password: a password-only authenticate() call can never
      // succeed for a 2FA-enabled account, which silently aborted this whole
      // fetch (the surrounding catch swallows it) every time this ran -
      // i.e. on every fresh POS session, since profilePictureBytes lives on
      // this widget's state and doesn't carry over to the next one. The
      // webview is already using this exact session, so there's no need to
      // authenticate again at all.
      final client = OdooClient(serverUrl, sessionId: session);
      try {
        final response = await client.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [userIdInt],
            ['image_1920'],
          ],
          'kwargs': {},
        });

        if (response.isNotEmpty) {
          final imageData = ImageUtils.base64Of(response[0]['image_1920']);
          if (imageData.isNotEmpty && mounted) {
            try {
              final bytes = base64Decode(imageData);
              if (ImageUtils.isValidImage(bytes)) {
                setState(() {
                  profilePictureBytes = bytes;
                });
              } else {
                setState(() {
                  profilePictureBytes = null;
                });
              }
            } catch (e) {
              setState(() {
                profilePictureBytes = null;
              });
            }
          }
        }
      } catch (e) {
        if (mounted) {}
      } finally {
        client.close();
      }
    } catch (e) {
      if (mounted) {}
    } finally {
      _isLoadingProfilePicture = false;
    }
  }

  void _updateProfilePicture(Uint8List newPictureBytes) {
    setState(() {
      profilePictureBytes = newPictureBytes;
    });
    _refreshWebProfile();
  }

  Future<void> _refreshWebProfile() async {
    if (webViewController != null && profilePictureBytes != null) {
      String jsCode = """
          var profileImg = document.querySelector('.o_user_menu .o_user_avatar, .o_main_navbar .oe_topbar_avatar');
          if (profileImg) {
            profileImg.src = 'data:${ImageUtils.isSvg(profilePictureBytes) ? 'image/svg+xml' : 'image/jpeg'};base64,${base64Encode(profilePictureBytes!)}';
            profileImg.onerror = function() {
              console.error('Failed to load profile image');
            };
          } else {
            console.warn('Profile image element not found');
          }
        """;
      await webViewController!.evaluateJavascript(source: jsCode);
    }
  }

  @override
  void initState() {
    super.initState();
    posUrl = '';
    getLink().then((_) {
      // Try to set cookie again after getLink completes
      if (webViewController != null) {
        setCookieHeader();
      }
    });
    // Load profile picture after a delay to not block initial load
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        _loadProfilePicture();
      }
    });

    // Check and show rating if criteria met
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewService().checkAndShowRating(context);
    });
  }

  @override
  void dispose() {
    // Cancel any pending async operations
    _isLoadingProfilePicture = false;
    _disarmLoadingSafetyTimer();
    super.dispose();
  }

  // The POS navbar's "Install App" item just calls window.open() to a PWA
  // install-helper URL (point_of_sale/navbar.xml) - inside this embedded
  // WebView that either does nothing or, per Android's popup-window
  // handling, leaves a "pending popup" that blocks any later window.open
  // call. It isn't useful here (the app is already installed), so hide it
  // instead of trying to make window.open work inside a WebView. Odoo's
  // dropdown menu content is only mounted into the DOM when opened, so a
  // MutationObserver is needed rather than a single pass right after load.
  Future<void> _hideInstallAppMenuItem() async {
    if (webViewController == null) return;
    const jsCode = """
      (function() {
        if (window.__moboHideInstallAppObserver) return;
        function hide() {
          document.querySelectorAll('.dropdown-item, .o-dropdown-item, [role="menuitem"]').forEach(function(el) {
            if (el.textContent && el.textContent.trim() === 'Install App') {
              el.style.display = 'none';
            }
          });
        }
        hide();
        window.__moboHideInstallAppObserver = new MutationObserver(hide);
        window.__moboHideInstallAppObserver.observe(document.body, { childList: true, subtree: true });
      })();
    """;
    try {
      await webViewController!.evaluateJavascript(source: jsCode);
    } catch (_) {}
  }

  Future<void> getLink() async {
    setState(() {
      isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    var serverUrl = prefs.getString("uri");
    var session_id = prefs.getString("session_id");
    var pos_id = prefs.getInt("pos_id");
    var dbName = prefs.getString("dbName");

    if (serverUrl == null || session_id == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const ServerSetupScreen()),
        (Route<dynamic> route) => false,
      );
      return;
    }

    // Check if POS configuration is selected
    if (pos_id == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/backend');
      }
      return;
    }

    String completeUrl = '$serverUrl/web';
    String pos_url =
        '${serverUrl!.replaceAll(RegExp(r'/+$'), '')}/pos/ui?config_id=$pos_id';
    Uri hostUrl = Uri.parse(serverUrl!);
    String domain_host = hostUrl.host;

    setState(() {
      posUrl = pos_url;
      currentUrl = completeUrl;
      sessionID = session_id;
      Domain = domain_host;
      this.serverUrl = serverUrl;
      this.dbName = dbName;
    });
  }

  Future<bool> validateSession() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/web/session/check'),
        headers: {
          'Cookie': 'session_id=$sessionID',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Commits the POS theme cookie to the native cookie jar, drops the cached
  // pages (HTTP cache) and reloads so the server re-renders with the chosen
  // asset bundle. See [_colorSchemeCookieHookJs].
  Future<void> _applyColorSchemeCookie(String scheme) async {
    if (scheme != 'dark' && scheme != 'light') return;
    try {
      await CookieManager.instance().setCookie(
        url: WebUri(posUrl),
        name: 'pos_color_scheme',
        value: scheme,
        path: '/',
        expiresDate:
            DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch,
        isHttpOnly: false,
      );
      await InAppWebViewController.clearAllCache();
      await webViewController?.reload();
    } catch (_) {}
  }

  Future<void> clearCookies() async {
    try {
      await cookieManager.deleteAllCookies();
    } catch (e) {}
  }

  Future<void> setCookieHeader() async {
    try {
      // Check if Domain is initialized
      if (Domain.isEmpty) {
        return;
      }

      cookieManager = CookieManager.instance();
      final expiresDate =
          DateTime.now().add(Duration(days: 3)).millisecondsSinceEpoch;

      await cookieManager.setCookie(
        url: WebUri(posUrl),
        name: "session_id",
        value: sessionID,
        expiresDate: expiresDate,
        domain: Domain,
        isHttpOnly: false,
        path: '/',
      );

      if (isInitialLoad) {
        isInitialLoad = false;
        // Read the cookie back so it is committed before the first request.
        await cookieManager.getCookie(url: WebUri(posUrl), name: "session_id");
        await webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(posUrl)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cookie Error: $e\nThis may cause authentication issues.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _switchAccount(Map<String, String> account) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Color(0xFFC03355),
                size: 40,
              ),
            ),
          ),
    );

    try {
      await cookieManager.deleteAllCookies();
      await InAppWebViewController.clearAllCache();

      final client = OdooClient(account['serverAddress']!);
      final response = await client.authenticate(
        account['database']!,
        account['username']!,
        account['password']!,
      );
      if (await DatabaseExpiry.isExpired(
        serverUrl: account['serverAddress']!,
        sessionId: response.id,
      )) {
        await DatabaseExpiry.markExpired(
          account['serverAddress']!,
          account['database']!,
        );
        throw const DatabaseExpiredException();
      }
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString("session_id", response.id);
      await prefs.setString("username", account['username']!);
      await prefs.setString("password", account['password']!);
      await prefs.setString("uri", account['serverAddress']!);
      await prefs.setString("dbName", account['database']!);
      await prefs.setBool("logoutAction", true);
      await prefs.setString("userId", response.userId.toString());
      await prefs.setString("userLogin", response.userLogin);
      await prefs.setString("userName", response.userName);
      await prefs.setString("partnerId", response.partnerId.toString());
      await prefs.setString("userLang", response.userLang);
      await prefs.setString("userTz", response.userTz);
      await prefs.setBool("isSystem", response.isSystem);
      await prefs.setString("serverVersion", response.serverVersion);
      await prefs.setString("companyId", response.companyId.toString());
      await prefs.setString(
        "allowedCompanies",
        response.allowedCompanies.toString(),
      );

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/webapp',
          (route) => false,
          arguments: {
            'serverUrl': account['serverAddress'],
            'dbName': account['database'],
            'username': account['username'],
            'password': account['password'],
            'sessionId': response.id,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              e is DatabaseExpiredException
                  ? DatabaseExpiredException.message
                  : 'Failed to switch account: $e',
            ),
          ),
        );
      }
    }
  }

  Future<List<Map<String, String>>> _getSignedAccountsWithCredentials() async {
    final isar = await IsarService.instance;
    final accounts = await isar.signedAccounts.where().findAll();
    final accountDetails =
        accounts
            .map(
              (account) => {
                'account': account.accountKey ?? '',
                'username': account.username ?? '',
                'password': account.password ?? '',
                'serverAddress': account.serverAddress ?? '',
                'database': account.database ?? '',
                'userNameDisplay':
                    account.userNameDisplay ?? account.username ?? '',
                'profileImage': account.profileImage ?? '',
              },
            )
            .toList();

    return accountDetails;
  }

  /// Called when the webview detects the current account's session has
  /// died. For a 2FA-enabled account this doesn't mean the account itself is
  /// gone — a password-only reauth can never work for it, but a fresh TOTP
  /// challenge will — so instead of [handleLogout]'s full destructive logout
  /// (removing the account, deleting its local profile, bouncing to server
  /// setup), silently hand off to [TwoFactorAuthPage] with the saved
  /// credentials already in hand, matching mobo FullSuite's
  /// `_attemptSilentRelogin` recovery. Falls back to the full logout when
  /// that's not applicable (not a 2FA account, missing credentials, a 2FA
  /// flow is already running for this server, or the handoff is looping).
  Future<void> _handleDeadSession({
    required bool twoFactorRequired,
    required String serverUrl,
    required String? dbName,
    required String? username,
    required String? password,
  }) async {
    if (twoFactorRequired &&
        TwoFactorAuth.activeServer != serverUrl &&
        dbName != null &&
        username != null &&
        password != null &&
        TwoFactorAuth.registerReloginHandoff()) {
      if (mounted) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (_) => TwoFactorAuthPage(
                  serverUrl: serverUrl,
                  database: dbName,
                  username: username,
                  password: password,
                  onSuccessRouteName: '/backend',
                ),
          ),
          (route) => false,
        );
      }
      return;
    }
    await handleLogout();
  }

  Future<void> handleLogout() async {
    setState(() => _isLoggingOut = true);

    try {
      await webViewController?.stopLoading();
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString("uri") ?? '';
      final database = prefs.getString("dbName") ?? '';
      final username = prefs.getString("username") ?? '';
      final accountKey = "$username@$database";

      List<String> signedAccounts =
          prefs.getStringList("signed_accounts") ?? [];
      signedAccounts.remove(accountKey);
      await prefs.setStringList("signed_accounts", signedAccounts);

      await prefs.remove("cred_${accountKey}_username");
      await prefs.remove("cred_${accountKey}_password");
      await prefs.remove("cred_${accountKey}_server");
      await prefs.remove("cred_${accountKey}_db");

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
      });

      await clearCookies();
      await clearSharedPref();

      final remainingAccounts = await _getSignedAccountsWithCredentials();
      if (remainingAccounts.isNotEmpty && mounted) {
        final nextAccount = remainingAccounts.first;
        await _switchAccount(nextAccount);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const ServerSetupScreen()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error during logout: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<bool> isUserLoggedIn(OdooClient client) async {
    try {
      await client.checkSession();
      return true;
    } on OdooSessionExpiredException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> convertBlobUrlToBase64(String blobUrl) async {
    String jsCode = """
          async function convertBlobToBase64(blobUrl) {
              try {
                  const response = await fetch(blobUrl);
                  const blob = await response.blob();
                  const reader = new FileReader();
                  reader.onloadend = () => window.flutter_inappwebview.callHandler('blobToBase64Handler', reader.result.split(',')[1]);
                  reader.readAsDataURL(blob);
              } catch (error) {
                  console.error('Error converting Blob to Base64:', error);
              }
          }
          convertBlobToBase64('$blobUrl');
      """;
    await webViewController?.evaluateJavascript(source: jsCode);
  }

  // Report downloads in the POS (e.g. the closing screen's "Daily Sale"
  // report) go through Odoo's download.js: it fetches the report as a Blob,
  // then creates a hidden `<a download href="blob:...">` and clicks it
  // (web/static/src/core/network/download.js). A real browser turns that
  // into a save/open prompt, but a WebView has no such UI for it, and
  // "blob:" URLs can't be resolved outside the page anyway (there's nothing
  // for Android's onDownloadStartRequest to fetch), so the click silently
  // did nothing. This intercepts exactly that click, reads the blob back to
  // base64 in JS, and hands it to Flutter to save and open.
  Future<void> _installDownloadInterceptor() async {
    if (webViewController == null) return;
    const jsCode = """
      (function() {
        if (window.__moboDownloadInterceptorInstalled) return;
        window.__moboDownloadInterceptorInstalled = true;
        document.addEventListener('click', function(event) {
          var anchor = event.target && event.target.closest ? event.target.closest('a[download]') : null;
          if (!anchor || !anchor.href || anchor.href.indexOf('blob:') !== 0) return;
          event.preventDefault();
          event.stopPropagation();
          var filename = anchor.getAttribute('download') || 'download';
          fetch(anchor.href)
            .then(function(res) { return res.blob(); })
            .then(function(blob) {
              var reader = new FileReader();
              reader.onloadend = function() {
                if (window.flutter_inappwebview) {
                  window.flutter_inappwebview.callHandler(
                    'moboPosDownload', filename, reader.result.split(',')[1]
                  );
                }
              };
              reader.readAsDataURL(blob);
            })
            .catch(function(err) { console.error('mobo download intercept failed', err); });
        }, true);
      })();
    """;
    try {
      await webViewController!.evaluateJavascript(source: jsCode);
    } catch (_) {}
  }

  Future<void> _saveAndOpenDownload(String filename, String base64Data) async {
    try {
      final bytes = base64Decode(base64Data);
      final dir = await getApplicationDocumentsDirectory();
      final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open downloaded file: $e')),
        );
      }
    }
  }

  Future<void> clearSharedPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_id');
      await prefs.remove('username');
      await prefs.remove('password');
      await prefs.remove('logoutAction');
      await prefs.remove('userId');
      await prefs.remove('userLogin');
      await prefs.remove('userName');
      await prefs.remove('partnerId');
      await prefs.remove('userLang');
      await prefs.remove('userTz');
      await prefs.remove('isSystem');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      await prefs.remove('serverVersion');
      await prefs.remove('dbName');
      await prefs.remove('uri');
      await prefs.remove('database');
      await prefs.remove('signed_account');
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ProfilePage(
                          onProfilePictureUpdated: _updateProfilePicture,
                        ),
                  ),
                );
                _refreshWebProfile();
              },
              icon:
                  profilePictureBytes != null
                      ? Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: ClipOval(
                          child:
                              (profilePictureBytes != null &&
                                      ImageUtils.isValidImage(
                                        profilePictureBytes,
                                      ))
                                  ? ImageUtils.memory(
                                    profilePictureBytes!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        color:
                                            isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                      );
                                    },
                                  )
                                  : Icon(
                                    Icons.person,
                                    color:
                                        isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                  ),
                        ),
                      )
                      : Icon(
                        Icons.person,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
            ),
          ],
          // Matches the app's own theme (see ThemeProvider), not the
          // WebView content's color scheme.
          backgroundColor: isDark ? const Color(0xFF1B1D26) : Colors.grey[50],
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                key: webViewKey,
                // The POS navbar's "Install App" item calls plain
                // `window.open(...)` (point_of_sale/navbar.xml) to open a
                // "/scoped_app" install-helper URL - it doesn't use the PWA
                // beforeinstallprompt API. A WebView silently drops
                // window.open unless javaScriptCanOpenWindowsAutomatically /
                // supportMultipleWindows are enabled and onCreateWindow is
                // implemented, which is why tapping it did nothing.
                initialSettings: InAppWebViewSettings(
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                  useOnDownloadStart: true,
                  useShouldOverrideUrlLoading: true,
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: _setMethodsPolyfillJs,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                  UserScript(
                    source: _colorSchemeCookieHookJs,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                // Fallback for a real (non-blob) download URL, in case
                // anything else in the POS ever triggers one directly -
                // hand it to the system browser/download manager, since
                // this WebView has no download UI of its own.
                onDownloadStartRequest: (controller, downloadStartRequest) async {
                  try {
                    await launchUrl(
                      Uri.parse(downloadStartRequest.url.toString()),
                      mode: LaunchMode.externalApplication,
                    );
                  } catch (_) {}
                },
                // The POS menu's "Backend" item navigates this WebView to
                // '/odoo/action-point_of_sale.action_client_pos_menu'. Odoo's
                // own backend client then bounces straight back into the
                // open POS session, so the user never actually reaches the
                // backend. Intercept it here and hand over to the app's
                // native backend (Shop list) screen instead.
                shouldOverrideUrlLoading: (controller, action) async {
                  final target = action.request.url?.toString() ?? '';
                  if (action.isForMainFrame && isOdooBackendUrl(target)) {
                    _leavePosForBackend();
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onCreateWindow: (controller, createWindowAction) async {
                  final url = createWindowAction.request.url;
                  if (url != null && isOdooBackendUrl(url.toString())) {
                    _leavePosForBackend();
                    return false;
                  }
                  // PWA "Add to Home Screen" only works in a real browser
                  // tab, not inside this embedded WebView, so hand it off
                  // to the system browser instead of trying to open it here.
                  if (url != null) {
                    try {
                      await launchUrl(
                        Uri.parse(url.toString()),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                  }
                  return false;
                },
                // Granting at the WebView level only works once the OS-level
                // runtime permission is held, so request CAMERA/RECORD_AUDIO
                // first — otherwise getUserMedia() (the POS barcode scanner)
                // fails and the camera never opens.
                onPermissionRequest: (controller, request) async {
                  final needed = <Permission>[];
                  for (final r in request.resources) {
                    if (r == PermissionResourceType.CAMERA) {
                      needed.add(Permission.camera);
                    } else if (r == PermissionResourceType.MICROPHONE) {
                      needed.add(Permission.microphone);
                    }
                  }
                  final statuses = needed.isNotEmpty
                      ? await needed.request()
                      : <Permission, PermissionStatus>{};
                  final granted = request.resources.where((r) {
                    if (r == PermissionResourceType.CAMERA) {
                      return statuses[Permission.camera]?.isGranted ?? false;
                    }
                    if (r == PermissionResourceType.MICROPHONE) {
                      return statuses[Permission.microphone]?.isGranted ??
                          false;
                    }
                    return true;
                  }).toList();
                  return PermissionResponse(
                    resources: granted,
                    action: granted.isNotEmpty
                        ? PermissionResponseAction.GRANT
                        : PermissionResponseAction.DENY,
                  );
                },
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  setCookieHeader();
                  controller.addJavaScriptHandler(
                    handlerName: 'moboColorScheme',
                    callback: (args) async {
                      if (args.isEmpty || posUrl.isEmpty) return;
                      await _applyColorSchemeCookie(args[0].toString());
                    },
                  );
                  controller.addJavaScriptHandler(
                    handlerName: 'moboPosDownload',
                    callback: (args) {
                      if (args.length < 2) return;
                      final filename = args[0] as String;
                      final base64Data = args[1] as String;
                      _saveAndOpenDownload(filename, base64Data);
                    },
                  );
                },
                onLoadStart: (controller, url) async {
                  if (!mounted) return;
                  setState(() {
                    isLoading = true;
                    loadingProgress = 0.0;
                  });
                  _armLoadingSafetyTimer();

                  final urlStr = url.toString();
                  final prefs = await SharedPreferences.getInstance();

                  // A redirect to the login page means the session died
                  // server-side (expired, invalidated, server restarted...),
                  // not that the user navigated away from the POS. Handle it
                  // here - via _handleDeadSession's silent 2FA relogin, or a
                  // full logout - BEFORE the generic "left the POS" check
                  // below, which would otherwise always win for a
                  // '/web/login' URL (it never starts with the POS path) and
                  // just clear pos_id + bounce to the Shop list without ever
                  // recovering the session, leaving a stale/broken session
                  // the next attempt would hit again.
                  if (isOdooLoginUrl(urlStr)) {
                    final username = prefs.getString("username");
                    final storedUserLogin = prefs.getString("userLogin");
                    final password = prefs.getString("password");
                    final authLogin = storedUserLogin ?? username;
                    final twoFactorRequired =
                        prefs.getBool('twoFactorRequired') ?? false;
                    await _handleDeadSession(
                      twoFactorRequired: twoFactorRequired,
                      serverUrl: serverUrl,
                      dbName: prefs.getString("dbName"),
                      username: authLogin,
                      password: password,
                    );
                    return;
                  }

                  // Redirect if we've genuinely left the POS app. Odoo's POS
                  // router (pos_router_service.js) uses history.pushState for
                  // in-app screens (product/payment/receipt/...), so the
                  // WebView's current URL drifts away from the exact
                  // `posUrl` ('.../pos/ui?config_id=X') the moment the user
                  // navigates anywhere inside the POS - e.g. to
                  // '.../pos/ui/1/product/<uuid>?config_id=1'. Comparing
                  // against that literal string meant ANY later real
                  // navigation event (a reload, or any server-triggered
                  // redirect) on such a drifted URL looked like "left the
                  // POS" and bounced back to the Shop list, even though the
                  // user was still inside the same POS session. Compare
                  // against just the '.../pos/ui' path instead so any URL
                  // still under the POS app is recognized as such.
                  // Compare by path: the stored server URL may end with '/',
                  // which would make a string prefix like '//pos/ui'
                  // never match the real '.../pos/ui/...' URL.
                  if (!_isPosUiUrl(urlStr)) {
                    // The session is no longer open in this webview, so clear
                    // the persisted pos_id too - otherwise a later cold start
                    // would still see a (now stale) pos_id and route straight
                    // back into WebViewApp instead of the Shop list, even
                    // though the user was actually left on the Shop list.
                    await prefs.remove('pos_id');
                    if (mounted) {
                      Navigator.popAndPushNamed(context, '/backend');
                    }
                    return;
                  }

                  final userId = prefs.getString("userId");
                  final userLogin = prefs.getString("userLogin");
                  final userName = prefs.getString("userName");
                  final partnerId = prefs.getString("partnerId");
                  final userLang = prefs.getString("userLang");
                  final userTz = prefs.getString("userTz");
                  final isSystem = prefs.getBool("isSystem");
                  final dbName = prefs.getString("dbName");
                  final serverVersion = prefs.getString("serverVersion");
                  final companyId = prefs.getString("companyId");

                  final session = OdooSession(
                    id: sessionID,
                    userId: int.parse(userId ?? '0'),
                    partnerId: int.parse(partnerId ?? '0'),
                    userLogin: userLogin ?? '',
                    userName: userName ?? '',
                    userLang: userLang ?? '',
                    userTz: userTz ?? '',
                    isSystem: isSystem ?? false,
                    dbName: dbName ?? '',
                    serverVersion: serverVersion ?? '',
                    companyId: int.parse(companyId ?? '0'),
                    allowedCompanies: [],
                  );

                  var client = OdooClient(serverUrl);

                  // Read once up front so both the reauth branch below and
                  // the dead-session recovery path can use them.
                  final username = prefs.getString("username");
                  final storedUserLogin = prefs.getString("userLogin");
                  final password = prefs.getString("password");
                  final authLogin = storedUserLogin ?? username;

                  try {
                    // A password-only authenticate() call can never succeed
                    // for an account that requires 2FA, and Odoo counts
                    // every rejected attempt toward its TOTP brute-force
                    // lockout. This handler fires on every navigation inside
                    // the POS webview, so retrying it unconditionally here
                    // would repeatedly hammer that lockout for 2FA accounts.
                    // Reuse the existing session instead of re-authenticating
                    // when we know 2FA is required (matches mobo FullSuite's
                    // _attemptSilentRelogin guard).
                    final twoFactorRequired =
                        prefs.getBool('twoFactorRequired') ?? false;
                    if (twoFactorRequired) {
                      client = OdooClient(serverUrl, sessionId: session);
                    } else if (authLogin != null &&
                        password != null &&
                        dbName != null) {
                      // CRITICAL: Re-authenticate the client for login check
                      await client.authenticate(dbName, authLogin, password);
                    }

                    bool isLoggedIn = await isUserLoggedIn(client);

                    if (url.toString() == '$serverUrl/' ||
                        url.toString() == '$serverUrl') {
                      if (!isLoggedIn) {
                        await _handleDeadSession(
                          twoFactorRequired: twoFactorRequired,
                          serverUrl: serverUrl,
                          dbName: dbName,
                          username: authLogin,
                          password: password,
                        );
                      }
                    }
                  } catch (e) {
                  } finally {
                    client.close();
                  }
                },
                onProgressChanged: (controller, progress) async {
                  if (!mounted) return;
                  setState(() {
                    loadingProgress = progress / 100;
                  });
                },
                // First launch after install: the first request can still go
                // out before the WebView has picked up the session cookie and
                // come back as the website 404 page. Re-apply the cookie and
                // retry the POS URL once; later loads are fine.
                onReceivedHttpError: (controller, request, errorResponse) async {
                  if (request.isForMainFrame != true ||
                      errorResponse.statusCode != 404 ||
                      _retriedFirstLoad ||
                      posUrl.isEmpty ||
                      !_isPosUiUrl(request.url.toString())) {
                    return;
                  }
                  _retriedFirstLoad = true;
                  isInitialLoad = true;
                  await setCookieHeader();
                },
                onLoadStop: (controller, url) async {
                  _disarmLoadingSafetyTimer();
                  await Future.delayed(const Duration(milliseconds: 500));
                  if (!mounted) return;
                  setState(() {
                    isLoading = false;
                  });
                  _refreshWebProfile();
                  _hideInstallAppMenuItem();
                  _installDownloadInterceptor();
                },
                onLoadError: (controller, url, code, message) {
                  _disarmLoadingSafetyTimer();
                  if (!mounted) return;
                  setState(() {
                    isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Loading error: $message')),
                  );
                },
              ),
              if (isLoading || _isLoggingOut) _buildModernLoading(),
            ],
          ),
        ),
      ),
    );
  }

  bool _isPosUiUrl(String url) {
    // Collapse repeated slashes: a stored server URL ending in '/' yields
    // '//pos/ui' for the initial load.
    final path = (Uri.tryParse(url)?.path ?? '').replaceAll(RegExp(r'/{2,}'), '/');
    return path == '/pos/ui' || path.startsWith('/pos/ui/');
  }

  Future<void> _leavePosForBackend() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pos_id');
    if (mounted) {
      Navigator.popAndPushNamed(context, '/backend');
    }
  }

  Widget _buildModernLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      child: Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: isDark ? Colors.white : Color(0xFFC03355),
          size: 40,
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(home: WebViewApp(), debugShowCheckedModeBanner: false),
  );
}
