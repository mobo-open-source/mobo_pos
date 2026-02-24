import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:isar_community/isar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_pos/Isarmodel/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/odoo_webapp/webapp.dart';
import 'package:mobo_pos/ui/dialogs/app_dialogs.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Isarmodel/Isar.dart';
import '../Loginpage/server_setup_screen.dart';
import '../services/review_service.dart';
import 'profile.dart';
import '../core/image_utils.dart';

class BackendPage extends StatefulWidget {
  @override
  _BackendPageState createState() => _BackendPageState();
}

class _BackendPageState extends State<BackendPage> {
  List<Map<String, dynamic>> posConfigs = [];
  int? selectedPosId;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  InAppWebViewController? webViewController;
  bool _isLoggingOut = false;
  late CookieManager cookieManager;
  Uint8List? profilePictureBytes;

  @override
  void initState() {
    super.initState();
    _checkPosInstallation();
    // Load profile image in background - don't block UI
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _loadProfileImage();
    });

    // Check and show rating if criteria met
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewService().checkAndShowRating(context);
    });
  }

  Future<void> _checkPosInstallation() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {

        final prefs = await SharedPreferences.getInstance();
        final serverUrl = prefs.getString("uri");
        final dbName = prefs.getString("dbName");
        final userId = int.tryParse(prefs.getString("userId") ?? "0");
        // FIX: Use userLogin for authentication, fallback to username only if userLogin is missing
        final userLogin = prefs.getString("userLogin");
        final username = prefs.getString("username"); // This might be display name
        final password = prefs.getString("password");
        final sessionId = prefs.getString("session_id");

        final authLogin = userLogin ?? username;


        if (serverUrl == null ||
            dbName == null ||
            userId == null ||
            password == null ||
            sessionId == null) {
          throw Exception(
            'Missing required authentication data: serverUrl=$serverUrl, dbName=$dbName, userId=$userId, sessionId=$sessionId',
          );
        }

        final session = OdooSession(
          id: sessionId,
          userId: userId,
          partnerId: int.parse(prefs.getString("partnerId") ?? "0"),
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

        final client = OdooClient(serverUrl);
        
        // CRITICAL: Re-authenticate the client with saved credentials
        if (authLogin == null || authLogin.isEmpty) {
             throw Exception('Missing login credentials (userLogin/username)');
        }
        await client.authenticate(dbName, authLogin, password);


        // Check if POS module is installed
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
          if (mounted) {
            await _showInstallationAlert(context);
          }
          return;
        }


        // Fetch POS configurations
        await _fetchPosConfigs(client);
        
        // Success - break out of retry loop
        return;
        
      } catch (e) {

        // Check if it's a transient network error
        bool isTransientError = e.toString().contains('Connection reset by peer') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection refused') ||
            e.toString().contains('Connection closed');

        if (isTransientError && retryCount < maxRetries - 1) {
          // Retry for transient errors
          retryCount++;
          await Future.delayed(Duration(seconds: 1));
          continue;
        }

        // Non-transient error or max retries reached
        String detailedError = 'Error checking POS installation: ${e.toString()}';

        if (e.toString().contains('500') ||
            e.toString().contains('Internal Server Error')) {
          detailedError =
              'Internal Server Error: Please check your Odoo server status and database connection.';
        } else if (e.toString().contains('session')) {
          detailedError =
              'Session Error: Your session may have expired. Please try logging in again.';
        } else if (e.toString().contains('authentication') ||
            e.toString().contains('login')) {
          detailedError =
              'Authentication Error: Please check your login credentials.';
        } else if (isTransientError) {
          detailedError =
              'Network connection error. Please check your internet connection and try again.';
        }

        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = detailedError;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(detailedError),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        
        return;
      }
    }
  }

  Future<void> _fetchPosConfigs(OdooClient client) async {
    try {

      // Skip session validation - fetch will fail if session is invalid
      final response = await client.callKw({
        'model': 'pos.config',
        'method': 'search_read',
        'args': [
          [],
          ['id', 'name', 'current_session_state', 'current_session_id'],
        ],
        'kwargs': {},
      });


      if (response.isEmpty) {
        if (mounted) {
          await _showApiEnableAlert(context);
        }
        return;
      }

      if (mounted) {
        setState(() {
          posConfigs = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }

    } catch (e) {

      // Check if it's a specific Odoo error
      if (e.toString().contains('500') ||
          e.toString().contains('Internal Server Error')) {
        errorMessage =
            'Internal Server Error: The server encountered an error. Please check:\n'
            '• Server is running properly\n'
            '• Database connection is working\n'
            '• POS module is correctly installed\n'
            '• User has proper permissions';
      } else if (e.toString().contains('403') ||
          e.toString().contains('Forbidden')) {
        errorMessage = e.toString();
      } else if (e.toString().contains('404')) {
        errorMessage = 'Not Found: POS module or configuration not found';
      } else {
        errorMessage = e.toString();
      }

      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateProfilePicture(Uint8List newPictureBytes) {
    setState(() {
      profilePictureBytes = newPictureBytes;
    });
    _refreshWebProfile();
  }

  Future<void> _loadProfileImage() async {
    try {

      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString("uri");
      final dbName = prefs.getString("dbName");
      final userId = prefs.getString("userId");
      // FIX: Use userLogin for authentication
      final userLogin = prefs.getString("userLogin");
      final username = prefs.getString("username");
      final password = prefs.getString("password");
      final sessionId = prefs.getString("session_id");

      final authLogin = userLogin ?? username;

      if (serverUrl == null ||
          dbName == null ||
          userId == null ||
          username == null ||
          password == null) {
        return;
      }

      final session = OdooSession(
        id: sessionId ?? '',
        userId: int.parse(userId),
        partnerId: int.parse(prefs.getString("partnerId") ?? "0"),
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

      final client = OdooClient(serverUrl);
      
      // CRITICAL: Re-authenticate the client with saved credentials
      if (authLogin != null && authLogin.isNotEmpty) {
          await client.authenticate(dbName, authLogin, password);
      }

      // Fetch user profile image from Odoo
      final userResponse = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [int.parse(userId)],
          ['image_1920'],
        ],
        'kwargs': {},
      });

      if (userResponse != null && userResponse.isNotEmpty && mounted) {
        final userData = userResponse[0];
        final profileImageBase64 = userData['image_1920'];

        if (profileImageBase64 != null &&
            profileImageBase64 is String &&
            profileImageBase64.isNotEmpty) {
          try {
            final imageBytes = base64Decode(profileImageBase64);
            if (ImageUtils.isValidImage(imageBytes)) {
              setState(() {
                profilePictureBytes = imageBytes;
              });
            } else {
            }
          } catch (e) {
          }
        } else {
        }
      }

      client.close();
    } catch (e) {
      // Don't show error to user as this is not critical functionality
    }
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

  Future<void> _openPosSession(int posId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString("uri");
      final dbName = prefs.getString("dbName");
      final userId = int.tryParse(prefs.getString("userId") ?? "0");
      // FIX: Use userLogin for authentication
      final userLogin = prefs.getString("userLogin");
      final username = prefs.getString("username");
      final password = prefs.getString("password");

      final authLogin = userLogin ?? username;

      if (serverUrl == null || dbName == null || userId == null || username == null || password == null) {
        throw Exception('Missing required authentication data');
      }

      final session = OdooSession(
        id: prefs.getString("session_id") ?? '',
        userId: userId,
        partnerId: int.parse(prefs.getString("partnerId") ?? "0"),
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

      final client = OdooClient(serverUrl);
      
      // CRITICAL: Re-authenticate the client before opening POS session
      if (authLogin == null || authLogin.isEmpty) {
           throw Exception('Missing login credentials');
      }
      await client.authenticate(dbName, authLogin, password);

      // Create new POS session
      final sessionId = await client.callKw({
        'model': 'pos.session',
        'method': 'create',
        'args': [
          {'user_id': userId, 'config_id': posId, 'state': 'opening_control'},
        ],
        'kwargs': {},
      });

      if (sessionId != null) {
        await prefs.setInt("pos_id", posId);

        // Track significant event: New POS Session Opened
        ReviewService().trackSignificantEvent();

        // Verify the POS ID was saved
        final savedPosId = prefs.getInt("pos_id");

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/webapp');
        }
      } else {
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening POS session: $e')),
        );
      }
    }
  }

  Widget _buildPosConfigItem(Map<String, dynamic> config) {
    final isSessionOpen = config['current_session_state'] != false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        if (isSessionOpen) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt("pos_id", config['id']);

          // Verify the POS ID was saved
          final savedPosId = prefs.getInt("pos_id");

          // Track significant event: POS Session Continued
          ReviewService().trackSignificantEvent();

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/webapp');
          }
        } else {
          if (mounted) {
            await _showConfirmationDialog(context, config['id']);
          }
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // POS Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withOpacity(.1)
                              : Color(0xFFC03355).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:  Icon(
                      Icons.point_of_sale,
                      color: isDark
                          ? Colors.white: Color(0xFFC03355),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config['name'] ?? 'POS Configuration',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xff101010),
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${config['id']}',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isSessionOpen, isDark),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    isSessionOpen
                        ? Icons.play_circle_filled
                        : Icons.play_circle_outline,
                    size: 16,
                    color: isSessionOpen ? Colors.green : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSessionOpen ? 'Session is active' : 'Session is closed',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: isSessionOpen ? Colors.green : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC03355),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (isSessionOpen) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt("pos_id", config['id']);

                      // Verify the POS ID was saved
                      final savedPosId = prefs.getInt("pos_id");

                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/webapp');
                      }
                    } else {
                      if (mounted) {
                        await _showConfirmationDialog(context, config['id']);
                      }
                    }
                  },
                  child: Text(
                    isSessionOpen ? 'Continue Selling' : 'Open Session',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isSessionOpen, bool isDark) {
    final statusColor = isSessionOpen ? Colors.green : Colors.grey;
    final textColor = isDark ? Colors.white : statusColor;
    final backgroundColor =
        isDark ? Colors.white.withOpacity(0.15) : statusColor.withOpacity(0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isSessionOpen ? 'Active' : 'Closed',
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: isDark ? FontWeight.bold : FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40.0),
        child: AppBar(
          title: Text(
            'Shop',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w500,
              fontSize: 20,
              color: textColor,
            ),
          ),
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
                // Reload profile image after returning from profile page
                await _loadProfileImage();
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
                              return Container(
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                                child: Icon(
                                  Icons.person,
                                  color: isDark ? Colors.grey[400] : Colors.grey,
                                  size: 20,
                                ),
                              );
                            },
                          )
                          : Container(
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                color: isDark ? Colors.grey[400] : Colors.grey,
                                size: 20,
                              ),
                            ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            isDark ? Colors.grey[700] : Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                          size: 20,
                        ),
                      ),
            ),
          ],
          backgroundColor: backgroundColor,
          automaticallyImplyLeading: false,
        ),
      ),
      body: _buildBody(),
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildModernLoading();
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkPosInstallation,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (posConfigs.isEmpty) {
      return const Center(child: Text('No POS configurations available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: posConfigs.length,
      itemBuilder: (context, index) {
        return _buildPosConfigItem(posConfigs[index]);
      },
    );
  }

  Future<void> _handleLogout() async {
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

  Future<void> clearCookies() async {
    try {
      await cookieManager.deleteAllCookies();
    } catch (e) {
    }
  }

  Future<void> _switchAccount(Map<String, String> account) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildModernLoading(),
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

  Future<void> clearSharedPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // CRITICAL: Preserve hasSeenGetStarted - user should NEVER see get started again
      final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted');
      
      await prefs.remove('session_id');
      await prefs.remove('username');
      await prefs.remove('password');
      await prefs.remove('uri');
      await prefs.remove('dbName');
      await prefs.remove('userId');
      await prefs.remove('userLogin');
      await prefs.remove('userName');
      await prefs.remove('partnerId');
      await prefs.remove('userLang');
      await prefs.remove('userTz');
      await prefs.remove('isSystem');
      await prefs.remove('serverVersion');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      await prefs.remove('pos_id');
      await prefs.remove('database');
      await prefs.remove('signed_account');
      
      // CRITICAL: Restore hasSeenGetStarted flag
      if (hasSeenGetStarted == true) {
        await prefs.setBool('hasSeenGetStarted', true);
      }
    } catch (e) {
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

  Future<void> _showInstallationAlert(BuildContext context) async {
    await AppDialogs.showConfirm(
      context,
      title: 'POS Module Not Installed',
      message:
          'The Point of Sale module is not installed. Please install it to continue.',
      confirmText: 'OK',
      cancelText: 'Close',
    );
    return _handleLogout();
  }

  Future<void> _showApiEnableAlert(BuildContext context) async {
    await AppDialogs.showConfirm(
      context,
      title: 'Configuration Required',
      message: "Please enable the 'Show in POS Mobile' field in POS settings.",
      confirmText: 'OK',
      cancelText: 'Close',
    );
    return _handleLogout();
  }

  Future<void> _showConfirmationDialog(BuildContext context, int posId) async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Confirm Session Opening',
      message: 'Are you sure you want to open a new POS session?',
      confirmText: 'Confirm',
      cancelText: 'Cancel',
    );
    if (confirmed == true) {
      _openPosSession(posId);
    }
  }
}
