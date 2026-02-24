import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_pos/Loginpage/server_setup_screen.dart';
import 'package:mobo_pos/Loginpage/user_login_screen.dart';
import 'package:mobo_pos/Loginpage/login_layout.dart';
import 'package:mobo_pos/Loginpage/reset_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:mobo_pos/odoo_webapp/webapp.dart';
import 'package:mobo_pos/services/review_service.dart';
import 'package:mobo_pos/services/storage_service.dart';

/// The primary login page supporting username and password authentication against an Odoo server.
class LoginPage extends StatefulWidget {
  final bool clearAll;
  final String? serverUrl;
  final String? database;
  final OdooClient? client;

  const LoginPage({
    super.key,
    this.clearAll = false,
    this.serverUrl,
    this.database,
    this.client,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _submitted = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  late String serverUrl;
  late String database;
  OdooClient? client;

  // Check if the Sign In button should be enabled
  bool get _isSignInButtonEnabled {
    final hasUsername = _usernameController.text.trim().isNotEmpty;
    final hasPassword = _passwordController.text.trim().isNotEmpty;
    return hasUsername && hasPassword && !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    if (widget.clearAll) {
      // Clear all session data if needed
      _clearAllData();
    }

    serverUrl = widget.serverUrl ?? '';
    database = widget.database ?? '';

    if (serverUrl.isEmpty || database.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _errorMessage = 'Server URL and database are required. Please go back and configure.';
        });
      });
    }

    if (widget.client != null) {
      client = widget.client;
    } else if (serverUrl.isNotEmpty) {
      client = OdooClient(serverUrl);
    }

    // Add listeners to text controllers to update button state
    _usernameController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);

    // Load saved username
    _loadSavedCredentials();
  }

  // Update button state when text fields change
  void _updateButtonState() {
    setState(() {
      // This will trigger a rebuild and update the button opacity
    });
  }

  // Clear all session data
  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // CRITICAL: Preserve hasSeenGetStarted - user should NEVER see get started again
    final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted');
    
    await prefs.clear();
    
    // CRITICAL: Restore hasSeenGetStarted flag
    if (hasSeenGetStarted == true) {
      await prefs.setBool('hasSeenGetStarted', true);
    }
  }

  // Load previously saved credentials
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('lastUsername');
    final savedUrl = prefs.getString('lastUrl');
    final savedDatabase = prefs.getString('lastDatabase');
    
    // If server URL and database are not provided via widget, load from preferences
    if (serverUrl.isEmpty && savedUrl != null && savedUrl.isNotEmpty) {
      serverUrl = savedUrl;
    }
    
    if (database.isEmpty && savedDatabase != null && savedDatabase.isNotEmpty) {
      database = savedDatabase;
    }
    
    // Initialize client if we have server URL
    if (client == null && serverUrl.isNotEmpty) {
      client = OdooClient(serverUrl);
    }
    
    if (savedUsername != null && savedUsername.isNotEmpty) {
      setState(() {
        _usernameController.text = savedUsername;
        // Clear error message if we now have all required data
        if (serverUrl.isNotEmpty && database.isNotEmpty) {
          _errorMessage = null;
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove listeners before disposing controllers
    _usernameController.removeListener(_updateButtonState);
    _passwordController.removeListener(_updateButtonState);
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Sign In',
      subtitle: 'Enter your credentials to access the app',
      backButton: Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        child: IconButton(
          icon: HugeIcon(icon:
            HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ServerSetupScreen(),
              ),
            );
          },
        ),
      ),
      child: Form(
        key: _loginFormKey,
        child: _buildLoginForm(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Username field
        LoginTextField(
          controller: _usernameController,
          hint: 'Username',
          prefixIcon: HugeIcons.strokeRoundedUser,
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Username is required';
            }
            return null;
          },
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        ),

        const SizedBox(height: 16),

        // Password field
        LoginTextField(
          controller: _passwordController,
          hint: 'Password',
          prefixIcon: HugeIcons.strokeRoundedLockPassword,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          suffixIcon: IconButton(
            icon: HugeIcon(icon:
              _isPasswordVisible
                  ? HugeIcons.strokeRoundedView
                  : HugeIcons.strokeRoundedViewOff,
              size: 20,
              color: Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Password is required';
            }
            return null;
          },
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
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
                    url: serverUrl,
                    database: database,
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
        LoginErrorDisplay(error: _errorMessage),
        const SizedBox(height: 8),

        // Login button
        LoginButton(
          text: 'Sign In',
          isLoading: _isLoading,
          isEnabled: _isSignInButtonEnabled,
          onPressed: _performLogin,
          loadingWidget: LoadingAnimationWidget.staggeredDotsWave(
            color: Colors.white,
            size: 20,
          ),
        ),
        
        // Error display
      ],
    );
  }

  // Perform login with credentials
  /// Validates credentials and performs the login request to the Odoo server.
  Future<void> _performLogin() async {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    if (serverUrl.isEmpty || database.isEmpty) {
      setState(() {
        _errorMessage = 'Server configuration missing. Please go back and setup server.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _submitted = true;
      _errorMessage = null;
    });

    try {
      // Ensure client is initialized
      client ??= OdooClient(serverUrl);


      final session = await client!.authenticate(
        database,
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );


      if (session != null && session.userId != null && session.userId! > 0) {
        final prefs = await SharedPreferences.getInstance();
        
        
        // Save all required authentication data for POS backend
        await prefs.setString('lastUrl', serverUrl);
        await prefs.setString('lastUsername', _usernameController.text.trim());
        await prefs.setString('lastDatabase', database);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('session_id', session.id);
        await prefs.setString('uri', serverUrl);
        await prefs.setString('database', database);
        
        // Additional POS-specific data (matching backend expectations exactly)
        await prefs.setString('serverUrl', serverUrl);
        await prefs.setString('dbName', database);
        await prefs.setString('userId', session.userId!.toString());
        await prefs.setString('sessionId', session.id);
        await prefs.setString('username', _usernameController.text.trim());
        await prefs.setString('userLogin', session.userLogin ?? _usernameController.text.trim());
        await prefs.setString('userName', session.userName ?? _usernameController.text.trim());
        await prefs.setString('password', _passwordController.text.trim());
        
        // Additional session data that might be needed
        await prefs.setString('partnerId', session.partnerId?.toString() ?? '0');
        await prefs.setString('userLang', session.userLang ?? 'en_US');
        await prefs.setString('userTz', session.userTz ?? 'UTC');
        await prefs.setBool('isSystem', session.isSystem ?? false);
        await prefs.setString('serverVersion', session.serverVersion ?? '');
        await prefs.setString('companyId', session.companyId?.toString() ?? '1');
        
        // Verify data was saved correctly
        final savedDbName = prefs.getString('dbName');
        final savedUserId = prefs.getString('userId');

        // Save account for switching
        final storageService = StorageService();
        await storageService.saveAccount({
          'username': session.userName ?? _usernameController.text.trim(),
          'userLogin': session.userLogin ?? _usernameController.text.trim(),
          'userId': session.userId,
          'sessionId': session.id,
          'serverVersion': session.serverVersion ?? '',
          'userLang': session.userLang ?? 'en_US',
          'partnerId': session.partnerId ?? 0,
          'userTimezone': session.userTz ?? 'UTC',
          'companyId': session.companyId ?? 1,
          'isSystem': session.isSystem ?? false,
          'uri': serverUrl,
          'dbName': database,
          'password': _passwordController.text.trim(),
          'image': '', // Image not fetched here easily
        });

        // Track significant event: Successful Login
        ReviewService().trackSignificantEvent();

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/backend');
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid credentials. Please check your username and password.';
          _isLoading = false;
          _submitted = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _parseLoginError(e.toString());
        _isLoading = false;
        _submitted = false;
      });
    }
  }

  // Parse Odoo error messages to user-friendly messages
  /// Converts Odoo-specific error strings into user-friendly localized error messages.
  String _parseLoginError(String error) {
    final errorLower = error.toLowerCase();
    
    // Check for common authentication errors
    if (errorLower.contains('access denied') || 
        errorLower.contains('invalid login') ||
        errorLower.contains('authentication failed') ||
        errorLower.contains('wrong login/password') ||
        errorLower.contains('invalid username or password') ||
        errorLower.contains('login failed')) {
      return 'Invalid username or password. Please check your credentials and try again.';
    }
    
    // Check for database errors
    if (errorLower.contains('database') && errorLower.contains('not found')) {
      return 'Database not found. Please check your server configuration.';
    }
    
    // Check for connection errors
    if (errorLower.contains('connection') || 
        errorLower.contains('network') ||
        errorLower.contains('timeout') ||
        errorLower.contains('unreachable')) {
      return 'Unable to connect to server. Please check your internet connection and server URL.';
    }
    
    // Check for server errors
    if (errorLower.contains('500') || errorLower.contains('internal server error')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    }
    
    // Check for permission errors
    if (errorLower.contains('permission') || errorLower.contains('access')) {
      return 'Access denied. Please check your user permissions.';
    }
    
    // Default fallback for unknown errors
    return 'Login failed. Please check your credentials and try again.';
  }
}
