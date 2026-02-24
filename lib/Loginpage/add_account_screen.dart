import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:isar_community/isar.dart';
import '../Isarmodel/Isar.dart';
import '../Isarmodel/user_profile.dart';
import '../odoo_webapp/webapp.dart';
import 'login_layout.dart';

/// Screen for adding an additional account to the current Odoo server.
class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  String? _serverUrl;
  String? _database;

  @override
  void initState() {
    super.initState();
    _loadCurrentSessionInfo();

    // Auto-focus email field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_emailFocus);
      }
    });
  }

  Future<void> _loadCurrentSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrl = prefs.getString('uri');
      _database = prefs.getString('dbName');
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _addAccount() async {
    if (_serverUrl == null || _database == null) {
      setState(() {
        _errorMessage = 'No active session found. Please login first.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {

      final client = OdooClient(_serverUrl!);
      
      // Authenticate with the new credentials
      final session = await client.authenticate(
        _database!,
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (session.id.isEmpty) {
        setState(() {
          _errorMessage = 'Authentication failed. Please check your credentials.';
          _isLoading = false;
        });
        return;
      }

      // Fetch company ID
      final companyResponse = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          ['company_id', 'company_ids']
        ],
        'kwargs': {},
      });

      int? companyId;
      if (companyResponse.isNotEmpty) {
        final userData = companyResponse[0];
        if (userData['company_id'] is List && userData['company_id'].isNotEmpty) {
          companyId = userData['company_id'][0];
        } else if (userData['company_ids'] is List && userData['company_ids'].isNotEmpty) {
          companyId = userData['company_ids'][0];
        }
      }

      if (companyId == null) {
        throw Exception('No company ID found for the user');
      }

      // Store the new account in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("session_id", session.id);
      await prefs.setString("username", _emailController.text.trim());
      await prefs.setString("password", _passwordController.text);
      await prefs.setString("uri", _serverUrl!);
      await prefs.setString("dbName", _database!);
      await prefs.setBool("logoutAction", true);
      await prefs.setString("userId", session.userId.toString());
      await prefs.setString("userLogin", session.userLogin);
      await prefs.setString("userName", session.userName);
      await prefs.setString("partnerId", session.partnerId.toString());
      await prefs.setString("userLang", session.userLang);
      await prefs.setString("userTz", session.userTz);
      await prefs.setBool("isSystem", session.isSystem);
      await prefs.setString("serverVersion", session.serverVersion);
      await prefs.setString("companyId", companyId.toString());

      // Fetch user image for avatar
      String profileImage = '';
      try {
        final userDetails = await client.callKw({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [session.userId],
            ['name', 'image_1920']
          ],
        });
        
        if (userDetails is List && userDetails.isNotEmpty) {
          final user = userDetails.first as Map;
          final img = user['image_1920'];
          if (img != null && img != false && img is String && img.isNotEmpty) {
            profileImage = img;
          }
        }
      } catch (e) {
      }

      // Store in Isar - check if account already exists
      final isar = await IsarService.instance;
      final accountKey = '${_emailController.text.trim()}@$_database';

      await isar.writeTxn(() async {
        // Check if account already exists by accountIdentifier (unique index)
        final existingAccount = await isar.signedAccounts
            .where()
            .accountIdentifierEqualTo(accountKey)
            .findFirst();

        if (existingAccount != null) {
          // Update existing account
          existingAccount.username = _emailController.text.trim();
          existingAccount.serverAddress = _serverUrl!;
          existingAccount.database = _database!;
          existingAccount.password = _passwordController.text;
          existingAccount.userNameDisplay = session.userName;
          existingAccount.accountKey = accountKey;
          existingAccount.profileImage = profileImage;
          
          await isar.signedAccounts.put(existingAccount);
        } else {
          // Create new account
          final signedAccount = SignedAccount()
            ..accountKey = accountKey
            ..username = _emailController.text.trim()
            ..serverAddress = _serverUrl!
            ..database = _database!
            ..password = _passwordController.text
            ..userNameDisplay = session.userName
            ..profileImage = profileImage
            ..accountIdentifier = accountKey;

          await isar.signedAccounts.put(signedAccount);
        }
      });
      

      
      client.close();

      if (!mounted) return;

      // Navigate to webapp
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/webapp',
        (route) => false,
        arguments: {
          'serverUrl': _serverUrl,
          'dbName': _database,
          'username': _emailController.text.trim(),
          'password': _passwordController.text,
          'sessionId': session.id,
        },
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account added and switched successfully'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFC03355),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add account: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Add Account',
      subtitle: 'Add another account to the same server',
      backButton: Positioned(
        top: 24,
        left: 0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 64,
              width: 64,
              alignment: Alignment.center,
              child:  HugeIcon(icon:
                HugeIcons.strokeRoundedArrowLeft01,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Server Info Display (optional)


            // Email Field
            LoginTextField(
              controller: _emailController,
              hint: 'Email',
              prefixIcon: HugeIcons.strokeRoundedMail01,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              focusNode: _emailFocus,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Field
            LoginTextField(
              controller: _passwordController,
              hint: 'Password',
              prefixIcon: HugeIcons.strokeRoundedLockPassword,
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              focusNode: _passwordFocus,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.black54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),

            // Error Display
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              LoginErrorDisplay(error: _errorMessage),
            ],

            const SizedBox(height: 24),

            // Add Account Button
            LoginButton(
              text: 'Add Account',
              isLoading: _isLoading,
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _addAccount();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

// Login Button Widget
/// A custom button widget styled for the login experience.
class LoginButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget? loadingWidget;

  const LoginButton({
    super.key,
    required this.text,
    required this.isLoading,
    this.onPressed,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? (loadingWidget ??
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ))
            : Text(
                text,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// Login Error Display Widget
/// A widget for displaying localized and user-friendly error messages on the login screen.
class LoginErrorDisplay extends StatelessWidget {
  final String? error;

  const LoginErrorDisplay({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    String _normalize(String msg) {
      final m = msg.toLowerCase();
      if (m.contains('incorrect username') ||
          m.contains('wrong login') ||
          m.contains('invalid username') ||
          m.contains('invalid password') ||
          m.contains('access denied') ||
          m.contains('authentication failed') ||
          m.contains('credential')) {
        return 'Incorrect username or password';
      }
      if (m.contains('no valid company')) {
        return 'No valid company assigned to this user';
      }
      if (m.contains('connection') || m.contains('network') || m.contains('timeout') || m.contains('socket')) {
        return 'Connection error. Please check your network and server URL.';
      }
      if (m.contains('database') || m.contains('db')) {
        return 'Database error. Please verify the database name.';
      }
      if (m.contains('http') || m.contains('404') || m.contains('500') || m.contains('502') || m.contains('503')) {
        return 'Server error. Please try again later.';
      }
      return msg;
    }

    final hasError = error != null && error!.trim().isNotEmpty;
    final display = hasError ? _normalize(error!) : '';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: hasError
          ? Container(
              key: const ValueKey('add_account_error_shown'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.30), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      display,
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('add_account_error_hidden')),
    );
  }
}
