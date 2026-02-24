import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:isar_community/isar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_pos/Isarmodel/user_profile.dart';
import 'package:mobo_pos/odoo_webapp/backend.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../Isarmodel/Isar.dart';
import 'profile.dart';
import '../Loginpage/server_setup_screen.dart';
import '../services/review_service.dart';
import '../core/image_utils.dart';

class WebViewApp extends StatefulWidget {
  const WebViewApp({Key? key}) : super(key: key);

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

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
  bool isLoading = true;
  bool showBarcodeScanner = false;
  bool _isLoggingOut = false;
  double loadingProgress = 0.0;
  String? dbName;
  bool _isLoadingProfilePicture = false;

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

      if (serverUrl == null || sessionId == null || partnerId == null || dbName == null || username == null || password == null) {
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

      var client = OdooClient(serverUrl, );
      
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
        final imageData = response[0]['image_1920'];
        if (imageData != false && imageData != null && mounted) {
          final bytes = base64Decode(imageData);
          if (ImageUtils.isValidImage(bytes)) {
            setState(() {
              profilePictureBase64 = imageData;
              profilePictureBytes = bytes;
            });
          } else {
          }
        }
      }

      client.close();
    } catch (e) {
      if (mounted) {
      }
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
      final password = prefs.getString("password");

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

    final client = OdooClient(serverUrl);
    try {
      // CRITICAL: Re-authenticate the client
      if (password != null) {
        final userLogin = prefs.getString("userLogin");
        final authLogin = userLogin ?? username;
        if (authLogin != null) {
             await client.authenticate(dbName, authLogin, password);
        }
      }
      
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
        final imageData = response[0]['image_1920'];
        if (imageData != false && imageData != null && mounted) {
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
      if (mounted) {
      }
    } finally {
      client.close();
    }
    } catch (e) {
      if (mounted) {
      }
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
            profileImg.src = 'data:image/jpeg;base64,${base64Encode(profilePictureBytes!)}';
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
    super.dispose();
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
    String pos_url = '$serverUrl/pos/ui?config_id=$pos_id';
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

  Future<void> clearCookies() async {
    try {
      await cookieManager.deleteAllCookies();
    } catch (e) {
    }
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
      builder: (context) => Container(
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
        ).showSnackBar(SnackBar(content: Text('Failed to switch account: $e')));
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
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: AppBar(
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
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: (profilePictureBytes != null && ImageUtils.isValidImage(profilePictureBytes))
                                ? Image.memory(
                                  profilePictureBytes!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    );
                                  },
                                )
                                : Icon(
                                    Icons.person,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                            ),
                          )
                        : Icon(
                          Icons.person,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[700],
                        ),
              ),
            ],
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : Colors.grey[50],
            automaticallyImplyLeading: false,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                key: webViewKey,
                onWebViewCreated: (controller) {
                  webViewController = controller;
                  setCookieHeader();
                },
                onLoadStart: (controller, url) async {
                  setState(() {
                    isLoading = true;
                    loadingProgress = 0.0;
                  });

                  // Redirect if URL does not start with posUrl
                  if (!url.toString().startsWith(posUrl)) {
                    if (mounted) {
                      Navigator.popAndPushNamed(context, '/backend');
                    }
                    return;
                  }

                  final prefs = await SharedPreferences.getInstance();
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

                  var client = OdooClient(serverUrl, );

                  try {
                    // CRITICAL: Re-authenticate the client for login check
                    final username = prefs.getString("username");
                    final userLogin = prefs.getString("userLogin");
                    final password = prefs.getString("password");
                    final authLogin = userLogin ?? username;
                    
                    if (authLogin != null && password != null && dbName != null) {
                      await client.authenticate(dbName, authLogin, password);
                    }
                    
                    bool isLoggedIn = await isUserLoggedIn(client);

                    if (url.toString().contains('/web/login')) {
                      await handleLogout();
                    }

                    if (url.toString() == '$serverUrl/' ||
                        url.toString() == '$serverUrl') {
                      if (!isLoggedIn) {
                        await handleLogout();
                      }
                    }
                  } catch (e) {
                  } finally {
                    client.close();
                  }
                },
                onProgressChanged: (controller, progress) async {
                  setState(() {
                    loadingProgress = progress / 100;
                  });
                },
                onLoadStop: (controller, url) async {
                  await Future.delayed(const Duration(milliseconds: 500));
                  setState(() {
                    isLoading = false;
                  });
                  _refreshWebProfile();
                },
                onLoadError: (controller, url, code, message) {
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
