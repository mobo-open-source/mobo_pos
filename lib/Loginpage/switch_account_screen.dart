import 'dart:async';
import 'package:isar_community/isar.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Isarmodel/Isar.dart';
import '../Isarmodel/user_profile.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/network_service.dart';
import '../core/style.dart';

/// Screen for adding a new account or switching between existing server configurations.
class SwitchAccountScreen extends StatefulWidget {
  const SwitchAccountScreen({super.key});

  @override
  State<SwitchAccountScreen> createState() => _SwitchAccountScreenState();
}

class _SwitchAccountScreenState extends State<SwitchAccountScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  List<String> _databases = [];
  String? _selectedDatabase;
  final NetworkService _networkService = NetworkService();
  Timer? _debounce;
  String selectedProtocol = 'https://';
  int _currentStep = 0;
  String? _workingProtocol;
  bool showError = false;

  @override
  void initState() {
    super.initState();
    _initializeUrl();
    _urlController.addListener(_onUrlChanged);
  }

  Future<void> _initializeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('uri') ?? '';
    if (url.isNotEmpty) {
       String processedUrl = url;
       if (url.startsWith('https://')) {
         selectedProtocol = 'https://';
         processedUrl = url.substring(8);
       } else if (url.startsWith('http://')) {
         selectedProtocol = 'http://';
         processedUrl = url.substring(7);
       }
      _urlController.text = processedUrl;
      _fetchDatabaseList();
    }
  }

  void _onUrlChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_urlController.text.isNotEmpty) {
        _fetchDatabaseList();
      }
    });
  }

  /// Fetches the list of databases for the current URL.
  Future<void> _fetchDatabaseList() async {
    try {
      setState(() {
        _isLoading = true;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = null;
        _workingProtocol = null;
      });

      String rawUrl = _urlController.text.trim();
      final match =
          RegExp(r'^(https?://)', caseSensitive: false).firstMatch(rawUrl);

      List<String> protocolsToTry = [];
      String host;

      if (match != null) {
        String detectedProtocol = match.group(1)!.toLowerCase();
        protocolsToTry = [detectedProtocol];
        host = rawUrl.substring(detectedProtocol.length);
      } else {
        host = rawUrl;
        protocolsToTry = [selectedProtocol];

        if (selectedProtocol == 'https://') {
          protocolsToTry.add('http://');
        } else {
          protocolsToTry.add('https://');
        }
      }

      bool success = false;
      dynamic lastError;

      for (String protocol in protocolsToTry) {
        try {
          final dbList =
              await _networkService.fetchDatabaseList('$protocol$host');

          if (dbList.isNotEmpty) {
            setState(() {
              _databases = dbList;
              _workingProtocol = protocol;
              _errorMessage = null;
            });

            final prefs = await SharedPreferences.getInstance();
            final currentDb = prefs.getString('dbName');
            
            setState(() {
              if (currentDb != null && _databases.contains(currentDb)) {
                _selectedDatabase = currentDb;
              } else if (_databases.isNotEmpty) {
                _selectedDatabase = _databases.first;
              } else {
                _selectedDatabase = null;
              }
            });

            success = true;
            break;
          }
        } catch (error) {
          lastError = error;
        }
      }

      if (!success) {
        setState(() {
          _databases = [];
          showError = true;
          _selectedDatabase = null;
          _workingProtocol = null;

          _errorMessage = _formatLoginError(lastError);
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = _formatLoginError(error);
        _databases = [];
        showError = true;
        _selectedDatabase = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatLoginError(dynamic error) {
    if (error == null) return "Unknown error occurred";
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
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
      return 'Login failed. Please check your credentials and server settings.';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _saveUserData(
      SharedPreferences prefs,
      OdooSession session,
      Map<String, dynamic> userData,
      Map<String, dynamic> availableFields,
      String url,
      String dbName) async {
    await prefs.setString("session_id", session.id);
    await prefs.setString("username", _usernameController.text);
    await prefs.setString("password", _passwordController.text);
    await prefs.setString("uri", url);
    await prefs.setString("dbName", dbName);
    await prefs.setBool("logoutAction", true);
    await prefs.setString("userId", session.userId.toString());
    await prefs.setString("userLogin", session.userLogin);
    await prefs.setString("userName", session.userName);
    await prefs.setString("partnerId", session.partnerId.toString());
    await prefs.setString("userLang", session.userLang);
    await prefs.setString("userTz", session.userTz);
    await prefs.setBool("isSystem", session.isSystem);
    await prefs.setString("serverVersion", session.serverVersion);
    await prefs.setString("companyId", session.companyId.toString());
    await prefs.setString(
        "allowedCompanies", session.allowedCompanies.toString());

    final isar = await IsarService.instance;
    final accountKey = url;
    final userProfile = UserProfile()
      ..userId = session.userId.toString()
      ..userName =
          userData['name'] is String ? userData['name'] : session.userName
      ..userEmail = userData['email'] is String ? userData['email'] : ''
      ..userPhone =
          userData['work_phone'] is String ? userData['work_phone'] : ''
      ..workLocation = userData['work_location_id'] is List &&
              userData['work_location_id'].isNotEmpty
          ? userData['work_location_id'][1] is String
              ? userData['work_location_id'][1]
              : ''
          : ''
      ..department = userData['department_id'] is List &&
              userData['department_id'].isNotEmpty
          ? userData['department_id'][0].toString()
          : ''
      ..language = userData['lang'] is String ? userData['lang'] : ''
      ..timezone = userData['tz'] is String ? userData['tz'] : ''
      ..emailSignature =
          userData['signature'] is String ? userData['signature'] : ''
      ..maritalStatus = userData['marital'] is String ? userData['marital'] : ''
      ..profileImageBase64 =
          userData['image_1920'] is String ? userData['image_1920'] : ''
      ..notificationByEmail = userData['notification_type'] is String &&
          userData['notification_type'] == 'email'
      ..notificationInOdoo = userData['notification_type'] is String &&
          userData['notification_type'] == 'inbox'
      ..odooBotStatus = userData['odoobot_state'] is String &&
          (userData['odoobot_state'] == 'onboarding' ||
              userData['odoobot_state'] == 'not_initialized')
      ..dbName = dbName
      ..serverUrl = url
      ..username = _usernameController.text
      ..password = _passwordController.text
      ..companyId = session.companyId.toString()
      ..accountKey = accountKey
      ..lastUpdated = DateTime.now();

    await isar.writeTxn(() async {
      final existingProfile = await isar.userProfiles
          .filter()
          .accountKeyEqualTo(accountKey)
          .findFirst();
      if (existingProfile != null) {
        userProfile.id = existingProfile.id;
      }
      await isar.userProfiles.put(userProfile);
    });
  }

  Future<void> _saveSignedAccountToIsar(
      Map<String, dynamic> userData,
      String userId,
      String companyId,
      String url,
      String dbName) async {
    final isar = await IsarService.instance;
    final accountKey = url;

    final signedAccount = SignedAccount()
      ..accountKey = accountKey
      ..username = _usernameController.text
      ..serverAddress = url
      ..database = dbName
      ..password = _passwordController.text
      ..userNameDisplay = userData['name'] is String
          ? userData['name']
          : _usernameController.text
      ..profileImage =
          userData['image_1920'] is String ? userData['image_1920'] : ''
      ..accountIdentifier = accountKey;

    await isar.writeTxn(() async {
      final existingAccount = await isar.signedAccounts
          .where()
          .accountIdentifierEqualTo(accountKey)
          .findFirst();
      if (existingAccount != null) {
        signedAccount.id = existingAccount.id;
      }
      await isar.signedAccounts.put(signedAccount);
    });
  }

  Future<void> _saveSignedAccountListingToIsar(
      Map<String, dynamic> userData, String url, String dbName) async {
    final isar = await IsarService.instance;
    final accountKey = url;

    final signedAccountListing = SignedAccountListing()
      ..accountKey = accountKey
      ..username = _usernameController.text
      ..serverAddress = url
      ..database = dbName
      ..password = _passwordController.text
      ..userNameDisplay = userData['name'] is String
          ? userData['name']
          : _usernameController.text
      ..profileImage =
          userData['image_1920'] is String ? userData['image_1920'] : ''
      ..lastLoginTime = DateTime.now()
      ..accountIdentifier = accountKey;

    await isar.writeTxn(() async {
      final existingAccount = await isar.signedAccountListings
          .where()
          .accountIdentifierEqualTo(accountKey)
          .findFirst();
      if (existingAccount != null) {
        signedAccountListing.id = existingAccount.id;
      }
      await isar.signedAccountListings.put(signedAccountListing);
    });
  }

  Future<void> _saveSignedAccount(String username, String database) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList('signed_accounts') ?? [];
    String account = '$username@$database';
    if (!accounts.contains(account) &&
        username.isNotEmpty &&
        database.isNotEmpty) {
      accounts.add(account);
      await prefs.setStringList('signed_accounts', accounts);
    }
  }

  /// Authenticates the user and adds the new account to the local storage.
  Future<void> _addAccount() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final url = '${_workingProtocol ?? selectedProtocol}${_urlController.text.trim()}';
      final dbName = _selectedDatabase ?? '';

      if (url.isEmpty || dbName.isEmpty) {
        throw Exception("Please select a server and database.");
      }

      final authService = AuthService();
      final session = await authService.authenticateOdoo(
        url: url,
        database: dbName,
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (session == null) throw Exception("Authentication failed.");

      final storageService = StorageService();
      await storageService.saveSession(session);
      await storageService.saveLoginState(
        isLoggedIn: true,
        database: dbName,
        url: url,
        password: _passwordController.text.trim(),
      );
      
      final client = OdooClient(url);
      await client.authenticate(dbName, _usernameController.text.trim(), _passwordController.text.trim());

      Map<String, dynamic> availableFields = {};
      try {
        final fieldsResponse = await client.callKw({
          'model': 'res.users',
          'method': 'fields_get',
          'args': [],
          'kwargs': {
            'attributes': ['type', 'selection']
          },
        });
        availableFields = fieldsResponse as Map<String, dynamic>;
      } catch (e) {}

      final fieldsToFetch = [
        'name',
        'email',
        'work_phone',
        'work_location_id',
        'department_id',
        'lang',
        'tz',
        'notification_type',
        'odoobot_state',
        'signature',
        'partner_id',
        'marital',
        'image_1920',
      ].where((field) => availableFields.containsKey(field)).toList();

      Map<String, dynamic> userData = {};
      if (fieldsToFetch.isNotEmpty) {
        try {
          final userResponse = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              fieldsToFetch
            ],
            'kwargs': {},
          });
          userData = userResponse.isNotEmpty ? userResponse[0] : {};
        } catch (e) {}
      }

      await storageService.saveAccount({
        'username': session.userName,
        'userLogin': session.userLogin,
        'userId': session.userId,
        'sessionId': session.id,
        'serverVersion': session.serverVersion,
        'userLang': session.userLang,
        'partnerId': session.partnerId,
        'userTimezone': session.userTz,
        'companyId': session.companyId,
        'isSystem': session.isSystem,
        'uri': url,
        'dbName': dbName,
        'password': _passwordController.text.trim(),
        'image': userData['image_1920'] ?? '',
      });
      await _saveUserData(prefs, session, userData, availableFields, url, dbName);
      await _saveSignedAccountToIsar(
          userData, session.userId.toString(), session.companyId.toString(), url, dbName);
      await _saveSignedAccountListingToIsar(userData, url, dbName);
      await _saveSignedAccount(_usernameController.text, dbName);

      if (context.mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/webapp',
          arguments: {
            'serverUrl': url,
            'dbName': dbName,
            'sessionId': session.id,
          },
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage("assets/loginbg.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? Colors.black.withOpacity(1)
                        : Colors.white.withOpacity(1),
                    BlendMode.dstATop,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading
                      ? null
                      : () {
                          if (_currentStep == 1) {
                            setState(() {
                              _currentStep = 0;
                            });
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                  borderRadius: BorderRadius.circular(32),
                  child: Container(
                    height: 64,
                    width: 64,
                    alignment: Alignment.center,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: _isLoading ? Colors.white54 : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/pos-icon.png',
                    fit: BoxFit.fitWidth,
                    height: 30,
                    width: 30,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.precision_manufacturing,
                        color: Color(0xFFC03355),
                        size: 20,
                      );
                    },
                  ),
                  SizedBox(width: 10),
                  Text(
                    'mobo POS',
                    style: const TextStyle(
                      fontFamily: 'YaroRg',
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const SizedBox(height: 45),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Add New Account",
                          style: AppStyle.font(
                              size: 32,
                              weight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your credentials to continue',
                        style: AppStyle.font(
                          color: Colors.white70,
                          size: 14,
                          weight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Form(
                        key: _loginFormKey,
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_currentStep == 0) ...[
                                _buildUrlInput(),
                                const SizedBox(height: 20),
                                if (_databases.isNotEmpty) ...[
                                  _buildDatabaseDropdown(),
                                  const SizedBox(height: 20),
                                ],
                              ] else ...[
                                _buildInputField(
                                  controller: _usernameController,
                                  label: "Username",
                                  icon: HugeIcons.strokeRoundedUser03,
                                ),
                                const SizedBox(height: 20),
                                _buildInputField(
                                  controller: _passwordController,
                                  label: "Password",
                                  obscure: true,
                                  icon: HugeIcons.strokeRoundedSquareLockPassword,
                                  isPasswordField: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: AppStyle.font(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (_currentStep == 0) {
                                    if (_loginFormKey.currentState!
                                        .validate()) {
                                      if (_databases.isNotEmpty &&
                                          _selectedDatabase == null) {
                                        setState(() {
                                          _errorMessage =
                                              "Please select a database";
                                        });
                                        return;
                                      }
                                      setState(() {
                                        _currentStep = 1;
                                        _errorMessage = null;
                                      });
                                    }
                                  } else {
                                    _addAccount();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Adding',
                                      style: AppStyle.font(
                                        size: 14,
                                        weight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    LoadingAnimationWidget.staggeredDotsWave(
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ],
                                )
                              : Text(
                                  _currentStep == 0 ? 'Next' : 'Add Account',
                                  style: AppStyle.font(
                                    color: Color(0xFFFFFFFF),
                                    size: 16,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    dynamic icon,
    Function(String)? onChanged,
    bool isPasswordField = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: isPasswordField ? !_isPasswordVisible : obscure,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '$label is required';
        }
        return null;
      },
      style: AppStyle.font(color: Colors.black),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: AppStyle.font(
            size: 14,
            weight: FontWeight.w400,
            color: Colors.black.withOpacity(.4)),
        prefixIcon: icon != null ? Padding(
          padding: const EdgeInsets.all(12.0),
          child: HugeIcon(icon: icon, color: isDark ? Colors.white70 : Colors.black26, size: 20),
        ) : null,
        suffixIcon: isPasswordField
            ? IconButton(
                icon: HugeIcon(
                  icon: _isPasswordVisible ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOff,
                  color: _isPasswordVisible ? Colors.black26 : Colors.black54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: AppStyle.font(
          color: Colors.white,
          weight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return Row(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              value: selectedProtocol,
              items: ['https://', 'http://']
                  .map((item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          style: AppStyle.font(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedProtocol = value!;
                  _fetchDatabaseList();
                });
              },
              buttonStyleData: const ButtonStyleData(
                height: 50,
                width: 85,
              ),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: TextFormField(
            controller: _urlController,
            style: AppStyle.font(color: Colors.black),
            decoration: InputDecoration(
              hintText: "Server URL",
              hintStyle: AppStyle.font(
                  size: 14,
                  weight: FontWeight.w400,
                  color: Colors.black.withOpacity(.4)),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Server URL is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField2<String>(
        value: _databases.contains(_selectedDatabase) ? _selectedDatabase : null,
        isExpanded: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedDatabase,
              color: Colors.black26,
              size: 20,
            ),
          ),
        ),
        hint: Text(
          'Select Database',
          style: AppStyle.font(
            size: 14,
            weight: FontWeight.w400,
            color: Colors.black.withOpacity(.4),
          ),
        ),
        items: _databases
            .map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: AppStyle.font(
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ))
            .toList(),
        validator: (value) {
          if (value == null) {
            return 'Please select a database';
          }
          return null;
        },
        onChanged: (value) {
          setState(() {
            _selectedDatabase = value;
          });
        },
        buttonStyleData: const ButtonStyleData(
          padding: EdgeInsets.only(right: 8),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.black45,
          ),
          iconSize: 24,
        ),
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
