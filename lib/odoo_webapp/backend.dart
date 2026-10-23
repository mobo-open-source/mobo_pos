import '../services/database_expiry.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:isar_community/isar.dart' hide FilterGroup;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_pos/Isarmodel/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/odoo_webapp/webapp.dart';
import 'package:mobo_pos/ui/dialogs/app_dialogs.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Isarmodel/Isar.dart';
import '../Loginpage/server_setup_screen.dart';
import '../Loginpage/switch_account_screen.dart';
import '../Loginpage/user_login_screen.dart';
import '../services/auth_service.dart';
import '../services/pos_access_service.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';
import 'profile.dart';
import '../core/image_utils.dart';
import '../core/company/widgets/company_selector_widget.dart';
import '../core/company/providers/company_provider.dart';
import '../widgets/custom_search_textfield.dart';
import '../widgets/premium_filter_bottom_sheet.dart';
import '../core/style.dart';
import '../providers/theme_provider.dart';

class BackendPage extends StatefulWidget {
  @override
  _BackendPageState createState() => _BackendPageState();
}

class _BackendPageState extends State<BackendPage> {
  List<Map<String, dynamic>> posConfigs = [];
  int? selectedPosId;
  bool isLoading = true;
  bool hasError = false;
  bool _requiresReLogin = false;
  String errorMessage = '';
  InAppWebViewController? webViewController;
  bool _isLoggingOut = false;
  late CookieManager cookieManager;
  Uint8List? profilePictureBytes;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showArchivedShops = false;
  bool _groupByCompany = false;

  List<Map<String, dynamic>> get _filteredConfigs {
    if (_searchQuery.isEmpty) return posConfigs;
    final query = _searchQuery.toLowerCase();
    return posConfigs
        .where((c) => (c['name']?.toString() ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    cookieManager = CookieManager.instance();
    _checkPosInstallation();
    // Load profile image in background - don't block UI
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _loadProfileImage();
    });

    // CompanyProvider.initialize() also runs once at raw app startup (see
    // main.dart), before the user has logged in - at that point
    // SharedPreferences' `isLoggedIn` isn't set yet, so it silently gives up
    // with an empty company list ("No companies" in the selector) and
    // nothing else automatically retries it. This Shop screen is only ever
    // reached after a successful login, so use it as a reliable point to
    // populate the list if that first attempt came up empty.
    final companyProvider = context.read<CompanyProvider>();
    if (companyProvider.companies.isEmpty && !companyProvider.isLoading) {
      companyProvider.initialize();
    }

    // Check and show rating if criteria met
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewService().checkAndShowRating(context);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        final username = prefs.getString(
          "username",
        ); // This might be display name
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

        if (authLogin == null || authLogin.isEmpty) {
          throw Exception('Missing login credentials (userLogin/username)');
        }

        final client = await AuthService().getAuthenticatedClient(
          url: serverUrl,
          database: dbName,
          username: authLogin,
          password: password,
          sessionId: sessionId,
          userId: userId,
          partnerId: int.tryParse(prefs.getString("partnerId") ?? "0") ?? 0,
          userLogin: prefs.getString("userLogin"),
          userName: prefs.getString("userName"),
          userLang: prefs.getString("userLang") ?? "en_US",
          userTz: prefs.getString("userTz") ?? "UTC",
          isSystem: prefs.getBool("isSystem") ?? false,
          serverVersion: prefs.getString("serverVersion") ?? "",
          companyId: int.tryParse(prefs.getString("companyId") ?? "1") ?? 1,
          twoFactorRequired: prefs.getBool("twoFactorRequired") ?? false,
        );

        final allowedCompanyIds = prefs
            .getStringList('selected_allowed_company_ids')
            ?.map((e) => int.tryParse(e) ?? -1)
            .where((e) => e > 0)
            .toList();
        final accessResult = await PosAccessService.checkAccess(
          client,
          allowedCompanyIds: allowedCompanyIds,
          showArchived: _showArchivedShops,
        );
        switch (accessResult.status) {
          case PosAccessStatus.moduleNotInstalled:
            if (mounted) await _showInstallationAlert(context);
            return;
          case PosAccessStatus.accessDenied:
            if (mounted) {
              setState(() => isLoading = false);
              await _showAccessDeniedAlert(context);
            }
            return;
          case PosAccessStatus.configMissing:
            if (mounted) await _showApiEnableAlert(context);
            return;
          case PosAccessStatus.ok:
            if (mounted) {
              setState(() {
                posConfigs = accessResult.configs;
                isLoading = false;
              });
            }
            // Success - break out of retry loop
            return;
        }
      } catch (e) {
        // Check if it's a transient network error
        bool isTransientError =
            e.toString().contains('Connection reset by peer') ||
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
        String detailedError =
            'Error checking POS installation: ${e.toString()}';
        bool requiresReLogin = false;

        if (e is TwoFactorSessionExpiredException) {
          detailedError = e.toString();
          requiresReLogin = true;
        } else if (e.toString().toLowerCase().contains('runbot')) {
          // A Runbot test server blocking this database from the caller's
          // network location — an external access restriction, not
          // something retrying or re-logging in can fix. This account was
          // never actually usable, so treat it the same as Access Denied /
          // Module Missing: show it as a proper popup and log out, rather
          // than leaving the account "logged in" on a database it can never
          // reach.
          if (mounted) {
            await _showRunbotBlockedAlert(context);
          }
          return;
        } else if (e.toString().contains('AccessError') ||
            e.toString().contains('not allowed to access')) {
          if (mounted) {
            await _showAccessDeniedAlert(context);
          }
          return;
        } else if (e.toString().contains('500') ||
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
            _requiresReLogin = requiresReLogin;
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

      if (authLogin == null || authLogin.isEmpty) return;

      final client = await AuthService().getAuthenticatedClient(
        url: serverUrl,
        database: dbName,
        username: authLogin,
        password: password,
        sessionId: sessionId,
        userId: int.parse(userId),
        partnerId: int.tryParse(prefs.getString("partnerId") ?? "0") ?? 0,
        userLogin: prefs.getString("userLogin"),
        userName: prefs.getString("userName"),
        userLang: prefs.getString("userLang") ?? "en_US",
        userTz: prefs.getString("userTz") ?? "UTC",
        isSystem: prefs.getBool("isSystem") ?? false,
        serverVersion: prefs.getString("serverVersion") ?? "",
        companyId: int.tryParse(prefs.getString("companyId") ?? "1") ?? 1,
        twoFactorRequired: prefs.getBool("twoFactorRequired") ?? false,
      );

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
        final profileImageBase64 = ImageUtils.base64Of(userData['image_1920']);

        if (profileImageBase64 != null &&
            profileImageBase64 is String &&
            profileImageBase64.isNotEmpty) {
          try {
            final imageBytes = base64Decode(profileImageBase64);
            if (ImageUtils.isValidImage(imageBytes)) {
              setState(() {
                profilePictureBytes = imageBytes;
              });
            } else {}
          } catch (e) {}
        } else {}
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

      if (serverUrl == null ||
          dbName == null ||
          userId == null ||
          username == null ||
          password == null) {
        throw Exception('Missing required authentication data');
      }

      if (authLogin == null || authLogin.isEmpty) {
        throw Exception('Missing login credentials');
      }

      final client = await AuthService().getAuthenticatedClient(
        url: serverUrl,
        database: dbName,
        username: authLogin,
        password: password,
        sessionId: prefs.getString("session_id"),
        userId: userId,
        partnerId: int.tryParse(prefs.getString("partnerId") ?? "0") ?? 0,
        userLogin: prefs.getString("userLogin"),
        userName: prefs.getString("userName"),
        userLang: prefs.getString("userLang") ?? "en_US",
        userTz: prefs.getString("userTz") ?? "UTC",
        isSystem: prefs.getBool("isSystem") ?? false,
        serverVersion: prefs.getString("serverVersion") ?? "",
        companyId: int.tryParse(prefs.getString("companyId") ?? "1") ?? 1,
        twoFactorRequired: prefs.getBool("twoFactorRequired") ?? false,
      );

      // Create new POS session
      final posSessionId = await client.callKw({
        'model': 'pos.session',
        'method': 'create',
        'args': [
          {'user_id': userId, 'config_id': posId, 'state': 'opening_control'},
        ],
        'kwargs': {},
      });

      if (posSessionId != null) {
        await prefs.setInt("pos_id", posId);

        // Track significant event: New POS Session Opened
        ReviewService().trackSignificantEvent();

        // Verify the POS ID was saved
        final savedPosId = prefs.getInt("pos_id");

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/webapp');
        }
      } else {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening POS session: $e')),
        );
      }
    }
  }

  Widget _buildPosConfigItem(Map<String, dynamic> config) {
    // current_session_state is false once a session is truly closed, but it
    // passes through 'closing_control' (cashier tapped "Close Register" and
    // still needs to confirm the cash count in the POS's own closing screen)
    // and 'opening_control' before ever becoming 'opened'. Treating any
    // non-false value as "active" (as this used to) made a session stuck in
    // closing_control still show "Continue Selling" as if nothing had
    // happened when the cashier tried to close it.
    final sessionState = config['current_session_state'];
    final isSessionOpen = sessionState == 'opened';
    final isClosingControl =
        sessionState == 'closing_control' || sessionState == 'opening_control';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        if (isSessionOpen || isClosingControl) {
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
                    child: Icon(
                      Icons.point_of_sale,
                      color: isDark ? Colors.white : Color(0xFFC03355),
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
                  _buildStatusBadge(isSessionOpen, isClosingControl, isDark),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    isSessionOpen
                        ? Icons.play_circle_filled
                        : isClosingControl
                        ? Icons.pending
                        : Icons.play_circle_outline,
                    size: 16,
                    color:
                        isSessionOpen
                            ? Colors.green
                            : isClosingControl
                            ? Colors.orange
                            : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSessionOpen
                        ? 'Session is active'
                        : isClosingControl
                        ? 'Session is closing - confirm cash count'
                        : 'Session is closed',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color:
                          isSessionOpen
                              ? Colors.green
                              : isClosingControl
                              ? Colors.orange
                              : Colors.grey[600],
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
                    backgroundColor: AppStyle.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (isSessionOpen || isClosingControl) {
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
                    isSessionOpen
                        ? 'Continue Selling'
                        : isClosingControl
                        ? 'Continue Closing'
                        : 'Open Session',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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

  Widget _buildStatusBadge(bool isSessionOpen, bool isClosingControl, bool isDark) {
    final statusColor =
        isSessionOpen ? Colors.green : isClosingControl ? Colors.orange : Colors.grey;
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
        isSessionOpen ? 'Active' : isClosingControl ? 'Closing' : 'Closed',
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
      appBar: AppBar(
        toolbarHeight: kToolbarHeight, // 56, same as other Mobo apps
        title: Text(
          'Shop',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textColor,
          ),
        ),
        actions: [
          CompanySelectorWidget(
            onCompanyChanged: () async {
              if (!mounted) return;
              final provider = context.read<CompanyProvider>();
              final companyName =
                  provider.selectedCompany?['name']?.toString() ?? 'company';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to $companyName'),
                  backgroundColor: Colors.green[700],
                  duration: const Duration(seconds: 2),
                ),
              );

              setState(() {
                isLoading = true;
                hasError = false;
              });
              await _checkPosInstallation();
            },
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
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
            child:
                profilePictureBytes != null
                    ? Container(
                      width: 40,
                      height: 40,
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
                                    return Container(
                                      color:
                                          isDark
                                              ? Colors.grey[700]
                                              : Colors.grey[300],
                                      child: Icon(
                                        Icons.person,
                                        color:
                                            isDark
                                                ? Colors.grey[400]
                                                : Colors.grey,
                                        size: 20,
                                      ),
                                    );
                                  },
                                )
                                : Container(
                                  color:
                                      isDark
                                          ? Colors.grey[700]
                                          : Colors.grey[300],
                                  child: Icon(
                                    Icons.person,
                                    color:
                                        isDark ? Colors.grey[400] : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                      ),
                    )
                    : CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          isDark ? Colors.grey[700] : Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        color: isDark ? Colors.grey[400] : Colors.grey,
                        size: 20,
                      ),
                    ),
          ),
          const SizedBox(width: 12),
        ],
        backgroundColor: backgroundColor,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CustomSearchTextField(
              controller: _searchController,
              readOnly: isLoading,
              hintText: 'Search by shop name',
              onChanged: (query) {
                setState(() => _searchQuery = query);
              },
              onFilterTap: () => _showFilterSheet(context),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      backgroundColor: backgroundColor,
    );
  }

  /// Filter & Group By bottom sheet for the shop list — same design as the
  /// Mobo CRM app's `PremiumFilterBottomSheet`. `pos.config` only exposes
  /// one real backend filter (Archived) and one meaningful grouping
  /// (Company), so those are the only options wired in.
  void _showFilterSheet(BuildContext context) {
    PremiumFilterBottomSheet.show(
      context: context,
      primaryColor: AppStyle.primaryColor,
      filterGroups: [
        FilterGroup(
          title: 'Status',
          options: [FilterOption(title: 'Archived', value: _showArchivedShops)],
        ),
      ],
      groupByOptions: [
        FilterGroup(
          title: 'Group By',
          options: [FilterOption(title: 'Company', value: _groupByCompany)],
        ),
      ],
      onApply: (values) async {
        final newShowArchived = values['status_archived'] == true;
        final newGroupByCompany = values['group_by_company'] == true;
        final archivedChanged = newShowArchived != _showArchivedShops;

        setState(() {
          _showArchivedShops = newShowArchived;
          _groupByCompany = newGroupByCompany;
          if (archivedChanged) {
            isLoading = true;
            hasError = false;
          }
        });

        if (archivedChanged) {
          await _checkPosInstallation();
        }
      },
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return _buildModernLoading();
    }

    if (hasError) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 200,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    _requiresReLogin ? _handleLogout : _checkPosInstallation,
                child: Text(_requiresReLogin ? 'Log In Again' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (posConfigs.isEmpty) {
      return Center(
        child: Text(
          _showArchivedShops
              ? 'No archived shops found'
              : 'No POS configurations available',
        ),
      );
    }

    final filteredConfigs = _filteredConfigs;
    if (filteredConfigs.isEmpty) {
      return Center(child: Text('No shops match "$_searchQuery"'));
    }

    if (_groupByCompany) {
      return _buildGroupedByCompany(filteredConfigs);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredConfigs.length,
      itemBuilder: (context, index) {
        return _buildPosConfigItem(filteredConfigs[index]);
      },
    );
  }

  /// Renders the shop list sectioned by company — the Group By > Company
  /// option in the filter sheet.
  Widget _buildGroupedByCompany(List<Map<String, dynamic>> configs) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final c in configs) {
      final companyField = c['company_id'];
      final companyName = (companyField is List && companyField.length > 1)
          ? companyField[1].toString()
          : 'No Company';
      groups.putIfAbsent(companyName, () => []).add(c);
    }
    final sortedKeys = groups.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final companyName = sortedKeys[index];
        final items = groups[companyName]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$companyName (${items.length})',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            ...items.map((c) => _buildPosConfigItem(c)),
          ],
        );
      },
    );
  }

  /// Logs the current account out and removes it from this device.
  ///
  /// When [allowAccountSwitch] is true (the default, used by the user-facing
  /// "Logout" action) and another signed-in account remains, that account is
  /// silently switched to instead of landing on server setup. Callers that
  /// represent "this specific account/server can't be used for POS" (module
  /// missing, access denied, config disabled) pass false, since silently
  /// switching to a different account there would hide the actual problem —
  /// the user needs to land on the login screen, not another account.
  /// Removes the current account from every local store (shared prefs'
  /// `signed_accounts`/cached creds, the Isar profile/account collections,
  /// [StorageService]'s `loggedInAccounts` list the profile screen's "Switch
  /// Accounts" reads, cookies) and returns whatever accounts are still
  /// signed in afterward — shared by every flow that logs the current
  /// account out, since which screen to land on next differs per flow.
  Future<List<Map<String, String>>> _removeCurrentAccountAndGetRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString("uri") ?? '';
    final database = prefs.getString("dbName") ?? '';
    final username = prefs.getString("username") ?? '';
    final accountKey = "$username@$database";

    List<String> signedAccounts = prefs.getStringList("signed_accounts") ?? [];
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
      await isar.signedAccountListings
          .where()
          .accountIdentifierEqualTo(accountKey)
          .deleteAll();
    });

    final userId = int.tryParse(prefs.getString("userId") ?? '') ?? 0;
    await StorageService().removeAccount({
      'userId': userId,
      'uri': serverUrl,
      'dbName': database,
    });

    await clearCookies();
    await clearSharedPref();

    return _getSignedAccountsWithCredentials();
  }

  Future<void> _handleLogout({bool allowAccountSwitch = true}) async {
    setState(() => _isLoggingOut = true);

    try {
      await webViewController?.stopLoading();
      final remainingAccounts = await _removeCurrentAccountAndGetRemaining();
      if (allowAccountSwitch && remainingAccounts.isNotEmpty && mounted) {
        final nextAccount = remainingAccounts.first;
        await _switchAccount(nextAccount);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        if (mounted) {
          Provider.of<ThemeProvider>(
            context,
            listen: false,
          ).setThemeMode(ThemeMode.light);
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

  /// Logs the current (unusable) account out and returns to whichever entry
  /// screen fits how it was reached: the Add Account screen if other
  /// accounts are still signed in (this account was added via switch/add
  /// account, so let the user try a different one there), or the plain
  /// login screen for this same server if this was a fresh login with no
  /// other account to fall back to.
  Future<void> _logoutToLoginOrAddAccount() async {
    setState(() => _isLoggingOut = true);

    try {
      await webViewController?.stopLoading();
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString("uri") ?? '';
      final database = prefs.getString("dbName") ?? '';

      final remainingAccounts = await _removeCurrentAccountAndGetRemaining();

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (!mounted) return;
      Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).setThemeMode(ThemeMode.light);

      if (remainingAccounts.isNotEmpty) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SwitchAccountScreen()),
          (Route<dynamic> route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (context) => UserLoginScreen(
                  serverUrl: serverUrl,
                  database: database,
                  client: OdooClient(serverUrl),
                ),
          ),
          (Route<dynamic> route) => false,
        );
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
    } catch (e) {}
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
      // Dark mode is a per-login preference, not a device-level one - every
      // account/server should start in light mode until the user opts in
      // again, so don't let it carry over across a logout.
      await prefs.remove('theme_mode');

      // CRITICAL: Restore hasSeenGetStarted flag
      if (hasSeenGetStarted == true) {
        await prefs.setBool('hasSeenGetStarted', true);
      }
    } catch (e) {}
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
    await AppDialogs.showModuleMissing(
      context,
      title: 'Module Missing',
      message:
          'The required "Point of Sale" module is not installed on this '
          'server. Please contact your administrator to enable it.',
      buttonText: 'Back to Login',
    );
    await _logoutToLoginOrAddAccount();
  }

  Future<void> _showAccessDeniedAlert(BuildContext context) async {
    try {
      await AppDialogs.showConfirm(
        context,
        title: 'Access Denied',
        message:
            "Your account doesn't have permission to access Point of Sale. "
            "Please contact your Odoo administrator to be added to the "
            "Point of Sale / User or Point of Sale / Administrator group.",
        confirmText: 'OK',
        cancelText: 'Close',
      );
    } finally {
      // Neither button leaves the user in a usable state (access is still
      // denied), so both Close and OK log the session out. Land on the login
      // screen rather than silently switching to another signed-in account,
      // which would hide that this account can't be used for POS.
      await _handleLogout(allowAccountSwitch: false);
    }
  }

  Future<void> _showApiEnableAlert(BuildContext context) async {
    try {
      await AppDialogs.showConfirm(
        context,
        title: 'Configuration Required',
        message:
            "Please enable the 'Show in POS Mobile' field in POS settings.",
        confirmText: 'OK',
        cancelText: 'Close',
      );
    } finally {
      // Neither button leaves the user in a usable state (the config is
      // still missing), so both Close and OK log the session out. Land on
      // the login screen rather than silently switching to another signed-in
      // account, which would hide that this account/server can't be used.
      await _handleLogout(allowAccountSwitch: false);
    }
  }

  Future<void> _showRunbotBlockedAlert(BuildContext context) async {
    try {
      await AppDialogs.showConfirm(
        context,
        title: 'Server Not Accessible',
        message:
            "This Runbot database is not accessible from your current "
            "network location. Please use a development database or "
            "contact the Runbot team.",
        confirmText: 'OK',
        cancelText: 'Close',
      );
    } finally {
      // This account was never actually usable (the server itself is
      // blocking it, not this account's permissions), so both Close and OK
      // log the session out rather than leaving it "logged in" to a
      // database it can never reach.
      await _handleLogout(allowAccountSwitch: false);
    }
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
