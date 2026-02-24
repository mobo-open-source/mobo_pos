import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_pos/odoo_webapp/webapp.dart';
import 'package:mobo_pos/Loginpage/server_setup_screen.dart';
import 'package:mobo_pos/Loginpage/reset_password_screen.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Isarmodel/user_profile.dart';
import '../Isarmodel/Isar.dart';
import '../services/storage_service.dart';
import 'login_layout.dart';

/// Screen for logging into a specific server and database with user credentials.
class UserLoginScreen extends StatefulWidget {
  final String serverUrl;
  final String database;
  final OdooClient client;

  const UserLoginScreen({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.client,
  });

  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _shouldValidate = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Load previously saved credentials
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    
    if (savedUsername != null && savedUsername.isNotEmpty) {
      setState(() {
        _usernameController.text = savedUsername;
      });
    }
  }

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  // Navigate back to server setup
  void _goBackToServerSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ServerSetupScreen(),
      ),
    );
  }

  // Perform login
  /// Authenticates the user and sets up the session for the webapp/backend.
  Future<void> _performLogin() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your username.';
      });
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();

    // Create a fresh client connection for authentication
    OdooClient? authClient;
    try {
      
      authClient = widget.client;
      
      
      // Try authentication with trimmed credentials
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      
      // Validate credentials are not empty after trimming
      if (username.isEmpty) {
        throw Exception('Username cannot be empty');
      }
      if (password.isEmpty) {
        throw Exception('Password cannot be empty');
      }
      
      // Add timeout to authentication
      final response = await authClient
          .authenticate(
            widget.database,
            username,
            password,
          )
          .timeout(const Duration(seconds: 30));
      

      // Fetch company information
      int? companyId;
      try {
        final companyResponse = await authClient.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [response.userId],
            ['company_id', 'company_ids']
          ],
          'kwargs': {},
        });

        if (companyResponse.isNotEmpty) {
          final userData = companyResponse[0];
          if (userData['company_id'] is List && userData['company_id'].isNotEmpty) {
            companyId = userData['company_id'][0];
          } else if (userData['company_ids'] is List &&
              userData['company_ids'].isNotEmpty) {
            companyId = userData['company_ids'][0];
          }
        }
      } catch (e) {
        companyId = response.companyId;
      }

      if (companyId == null) {
        throw Exception('No valid company ID found for the user');
      }


      OdooSession updatedSession;
      try {
        updatedSession = OdooSession(
          id: response.id,
          userId: response.userId,
          partnerId: response.partnerId,
          userLogin: response.userLogin,
          userName: response.userName,
          userLang: response.userLang,
          userTz: response.userTz,
          isSystem: response.isSystem,
          dbName: response.dbName,
          serverVersion: response.serverVersion,
          companyId: companyId,
          allowedCompanies: [],
        );
      } catch (sessionError) {
        throw Exception('Failed to create session: $sessionError');
      }

      // Fetch minimal user data - only essential fields
      Map<String, dynamic> userData = {};
      try {
        final userResponse = await authClient.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [[response.userId], ['name', 'email', 'partner_id', 'image_1920']],
          'kwargs': {},
        });
        userData = userResponse.isNotEmpty ? userResponse[0] : {};
      } catch (e) {
        // Continue with empty userData
      }

      // Save user data
      final storageService = StorageService();
      await storageService.saveAccount({
        'username': updatedSession.userName,
        'userLogin': updatedSession.userLogin,
        'userId': updatedSession.userId,
        'sessionId': updatedSession.id,
        'serverVersion': updatedSession.serverVersion,
        'userLang': updatedSession.userLang,
        'partnerId': updatedSession.partnerId,
        'userTimezone': updatedSession.userTz,
        'companyId': updatedSession.companyId,
        'isSystem': updatedSession.isSystem,
        'uri': widget.serverUrl,
        'dbName': widget.database,
        'password': _passwordController.text,
        'image': userData['image_1920'] ?? '',
      });
      await _saveUserData(prefs, updatedSession, userData, {});
      
      // Save signed account data (non-critical)
      try {
        await _saveSignedAccountToIsar(userData);
      } catch (e) {
        // Continue anyway
      }
      
      await _saveSignedAccount(_usernameController.text.trim(), widget.database);

      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/backend',
        );
      }
    } on SocketException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      String errorMessage;
      if (e.toString().contains('Network is unreachable')) {
        errorMessage = 'No internet connection. Please check your network settings.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Server is not responding. Please verify the server URL is correct.';
      } else {
        errorMessage = 'Network error occurred. Please check your internet connection and server URL.';
      }

      // Clear invalid session data
      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      authClient?.close();
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      String errorMessage = 'Connection timed out. The server may be slow or unreachable. Please try again.';

      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      authClient?.close();
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      String errorMessage;
      if (e.toString().toLowerCase().contains('html')) {
        errorMessage = 'Invalid server response. This may not be an Odoo server or the URL is incorrect.';
      } else {
        errorMessage = 'Server sent invalid data. Please verify this is an Odoo server.';
      }

      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      authClient?.close();
    } on OdooException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      final message = e.message.toLowerCase();
      String errorMessage;
      
      if (message.contains('invalid login') || message.contains('access denied')) {
        errorMessage = 'Incorrect email or password. Please check your login credentials.';
      } else if (message.contains('database')) {
        errorMessage = 'Database access failed. Please verify the selected database is correct.';
      } else {
        errorMessage = _formatOdooError(e);
      }

      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      authClient?.close();
    } on HandshakeException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      String errorMessage;
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED') || 
          e.toString().contains('unable to get local issuer certificate')) {
        errorMessage = 'SSL certificate verification failed. The server certificate is not trusted. Try using HTTP instead of HTTPS.';
      } else {
        errorMessage = 'SSL handshake failed. Try using HTTP instead of HTTPS or contact your administrator.';
      }

      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      authClient?.close();
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      String errorMessage = _formatLoginError(e);

      // Clear invalid session data
      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
      
      authClient?.close();
    }
  }

  String _formatOdooError(OdooException e) {
    final message = e.message.toLowerCase();
    
    if (message.contains('404') || message.contains('not found')) {
      return 'Server not found. Please verify your server URL is correct and the server is running.';
    } else if (message.contains('403') || message.contains('forbidden')) {
      return 'Access denied. The server may not allow database listing or requires authentication.';
    } else if (message.contains('500') || message.contains('internal server error')) {
      return 'Server error occurred. Please contact your system administrator or try again later.';
    } else if (message.contains('timeout') || message.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    } else if (message.contains('ssl') || message.contains('certificate')) {
      return 'SSL certificate error. Try using HTTP instead of HTTPS, or contact your administrator.';
    } else if (message.contains('connection refused') || message.contains('refused')) {
      return 'Connection refused. Please verify the server URL and port number are correct.';
    } else {
      return 'Unable to connect to server. Please check your server URL and internet connection.';
    }
  }

  String _formatLoginError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('html instead of json') || errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') || errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') || errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database') && errorStr.contains('not found')) {
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
    } else if (errorStr.contains('no valid company')) {
      return 'No valid company assigned to this user.';
    } else if (errorStr.contains('accessdenied') || 
               errorStr.contains('access denied') ||
               errorStr.contains('invalid username') ||
               errorStr.contains('invalid password') ||
               errorStr.contains('wrong login') ||
               errorStr.contains('authentication failed') ||
               errorStr.contains('credential')) {
      return 'Incorrect username or password. Please check your login credentials.';
    } else {
      return 'Login failed. Please check your credentials and server settings.';
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserData(
      SharedPreferences prefs,
      OdooSession session,
      Map<String, dynamic> userData,
      Map<String, dynamic> availableFields,
      ) async {
    await prefs.setString("session_id", session.id.toString());
    await prefs.setString("username", _usernameController.text.trim());
    await prefs.setString("password", _passwordController.text);
    await prefs.setString("uri", widget.serverUrl);
    await prefs.setString("dbName", widget.database);
    await prefs.setString("database", widget.database);
    await prefs.setBool("logoutAction", true);
    await prefs.setString("userId", session.userId.toString());
    await prefs.setString("userLogin", session.userLogin.toString());
    await prefs.setString("userName", session.userName.toString());
    await prefs.setString("partnerId", session.partnerId.toString());
    await prefs.setString("userLang", session.userLang.toString());
    await prefs.setString("userTz", session.userTz.toString());
    await prefs.setBool("isSystem", session.isSystem);
    await prefs.setString("serverVersion", session.serverVersion.toString());
    await prefs.setString("companyId", session.companyId.toString());
    await prefs.setString("allowedCompanies", session.allowedCompanies.toString());

    // Save to Isar - handle unique constraint violation
    final isar = await IsarService.instance;
    final accountKey = '${_usernameController.text.trim()}@${widget.database}';
    
    final userProfile = UserProfile()
      ..userId = session.userId.toString()
      ..userName = availableFields.containsKey('name')
          ? (userData['name']?.toString() ?? session.userName.toString())
          : session.userName.toString()
      ..userEmail = availableFields.containsKey('email')
          ? (userData['email']?.toString() ?? '')
          : ''
      ..userPhone = (userData['phone']?.toString() ?? 
                   userData['work_phone']?.toString() ?? '')
      ..userMobile = (userData['mobile']?.toString() ?? 
                    userData['work_mobile']?.toString() ?? 
                    userData['partner_mobile']?.toString() ?? '')
      ..userWebsite = (userData['website']?.toString() ?? 
                     userData['work_website']?.toString() ?? 
                     userData['partner_website']?.toString() ?? '')
      ..userFunction = (userData['function']?.toString() ?? 
                      userData['job_title']?.toString() ?? 
                      userData['partner_function']?.toString() ?? '')
      ..workLocation = availableFields.containsKey('work_location_id')
          ? (userData['work_location_id'] != null && userData['work_location_id'] is List
          ? userData['work_location_id'][0].toString()
          : userData['work_location_id']?.toString() ?? '')
          : ''
      ..department = availableFields.containsKey('department_id')
          ? (userData['department_id'] != null && userData['department_id'] is List
          ? userData['department_id'][0].toString()
          : userData['department_id']?.toString() ?? '')
          : ''
      ..language = availableFields.containsKey('lang')
          ? (userData['lang']?.toString() ?? session.userLang.toString())
          : session.userLang.toString()
      ..timezone = availableFields.containsKey('tz')
          ? (userData['tz']?.toString() ?? session.userTz.toString())
          : session.userTz.toString()
      ..notificationByEmail = availableFields.containsKey('notification_type')
          ? (userData['notification_type'] == 'email')
          : true
      ..odooBotStatus = availableFields.containsKey('odoobot_state')
          ? (userData['odoobot_state'] != 'not_initialized')
          : false
      ..emailSignature = availableFields.containsKey('signature')
          ? (userData['signature']?.toString() ?? '')
          : ''
      ..maritalStatus = availableFields.containsKey('marital')
          ? (userData['marital']?.toString() ?? '')
          : ''
      ..profileImageBase64 = availableFields.containsKey('image_1920')
          ? (userData['image_1920']?.toString() ?? '')
          : ''
      ..companyId = session.companyId.toString()
      ..dbName = widget.database
      ..serverUrl = widget.serverUrl
      ..username = _usernameController.text.trim()
      ..password = _passwordController.text
      ..accountKey = accountKey
      ..lastUpdated = DateTime.now();

    try {
      await isar.writeTxn(() async {
        await isar.userProfiles.put(userProfile);
      });
    } catch (e) {
      // Continue anyway - SharedPreferences data is sufficient for login
    }
  }

  // Save signed account to Isar
  Future<void> _saveSignedAccountToIsar(Map<String, dynamic> userData) async {
    final isar = await IsarService.instance;
    final signedAccount = SignedAccount()
      ..accountKey = '${_usernameController.text.trim()}@${widget.database}'
      ..username = _usernameController.text.trim()
      ..serverAddress = widget.serverUrl
      ..database = widget.database
      ..password = _passwordController.text
      ..userNameDisplay = userData['name']?.toString() ?? ''
      ..profileImage = userData['image_1920']?.toString() ?? ''
      ..accountIdentifier = '${_usernameController.text.trim()}@${widget.database}';

    try {
      await isar.writeTxn(() async {
        await isar.signedAccounts.put(signedAccount);
      });
    } catch (e) {
      // Continue anyway - not critical for login
    }
  }

  // Save signed account
  Future<void> _saveSignedAccount(String username, String database) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('signed_account', '$username@$database');
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Sign In POS App',
      subtitle: 'Enter your credentials to continue',
      backButton: Positioned(
        top: 50,
        left: 16,
        child: IconButton(
          onPressed: _goBackToServerSetup,
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
            size: 20,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
      child: _buildLoginForm(),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Username field
          LoginTextField(
            controller: _usernameController,
            hint: 'Username',
            prefixIcon: HugeIcons.strokeRoundedUser,
            focusNode: _usernameFocusNode,
            enabled: !_isLoading,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: _shouldValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            validator: (value) {
              if (_shouldValidate && (value == null || value.trim().isEmpty)) {
                return 'Username is required';
              }
              return null;
            },
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
          
          const SizedBox(height: 16),
          
          // Password field
          LoginTextField(
            controller: _passwordController,
            hint: 'Password',
            prefixIcon: HugeIcons.strokeRoundedLockPassword,
            focusNode: _passwordFocusNode,
            enabled: !_isLoading,
            obscureText: _obscurePassword,
            autovalidateMode: _shouldValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            validator: (value) {
              if (_shouldValidate && (value == null || value.isEmpty)) {
                return 'Password is required';
              }
              return null;
            },
            suffixIcon: IconButton(
              onPressed: _togglePasswordVisibility,
              icon: HugeIcon(icon:
                _obscurePassword
                    ? HugeIcons.strokeRoundedViewOff
                    : HugeIcons.strokeRoundedView,
                size: 20,
                color: Colors.black54,
              ),
            ),
            onChanged: (value) {
              if (_errorMessage != null) {
                setState(() {
                  _errorMessage = null;
                });
              }
            },
          ),
          
          const SizedBox(height: 8),
          
          // Forgot Password Button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResetPasswordScreen(
                      url: widget.serverUrl,
                      database: widget.database,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Error display
          LoginErrorDisplay(error: _errorMessage),
          
          // Sign In button
          LoginButton(
            text: 'Sign In',
            isLoading: _isLoading,
            loadingWidget: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Signing In...',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            onPressed: () {
              setState(() {
                _shouldValidate = true;
              });
              if (_formKey.currentState?.validate() ?? false) {
                _performLogin();
              }
            },
          ),
        ],
      ),
    );
  }
}
