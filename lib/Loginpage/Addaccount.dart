import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar_community/isar.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';
import '../Isarmodel/user_profile.dart';
import '../Isarmodel/Isar.dart';
import 'login_layout.dart';

/// Page for adding a new Odoo account to the application.
class AddAccountLoginPage extends StatefulWidget {
  final String serverUrl;
  final String dbName;

  const AddAccountLoginPage({
    Key? key,
    required this.serverUrl,
    required this.dbName,
  }) : super(key: key);

  @override
  _AddAccountLoginPageState createState() => _AddAccountLoginPageState();
}

class _AddAccountLoginPageState extends State<AddAccountLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String? _selectedDatabase;
  bool _isLoading = false;
  bool _obscureText = true;
  bool _shouldValidate = false;
  String? _errorMessage;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> _addAccount() async {
    if (usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your username';
      });
      return;
    }
    if (passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final prefs = await SharedPreferences.getInstance();
    List<String> signedAccounts = prefs.getStringList('signed_accounts') ?? [];
    String accountKey = '${usernameController.text.trim()}@${widget.dbName}';

    if (signedAccounts.contains(accountKey)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Account already exists';
      });
      return;
    }

    // Clear cookies and cache
    await CookieManager.instance().deleteAllCookies();
    await InAppWebViewController.clearAllCache();

    final client = OdooClient(widget.serverUrl);

    try {
      final response = await client.authenticate(
        widget.dbName,
        usernameController.text,
        passwordController.text,
      );

      // Fetch the current default company ID
      final companyResponse = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [response.userId],
          ['company_id', 'company_ids']
        ],
        'kwargs': {},
      });

      int? updatedCompanyId;
      List<dynamic> allowedCompanies = [];
      if (companyResponse.isNotEmpty) {
        final userData = companyResponse[0];
        log('Company data: ${userData['company_id']}, ${userData['company_ids']}');
        if (userData['company_id'] is List && userData['company_id'].isNotEmpty) {
          updatedCompanyId = userData['company_id'][0];
        } else if (userData['company_ids'] is List && userData['company_ids'].isNotEmpty) {
          updatedCompanyId = userData['company_ids'][0];
        }
        allowedCompanies = userData['company_ids'] ?? [];
      }

      if (updatedCompanyId == null) {
        throw Exception('No company ID found for the user');
      }

      // Update OdooSession with the new company ID
      final updatedSession = OdooSession(
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
        companyId: updatedCompanyId,
        allowedCompanies: [],
      );

      // Fetch user profile data
      final fieldsResponse = await client.callKw({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [],
        'kwargs': {'attributes': ['type', 'selection']}
      });
      final availableFields = fieldsResponse as Map<String, dynamic>;

      // Check specifically for phone-related fields
      final phoneFields = availableFields.keys.where((key) => 
        key.toLowerCase().contains('phone') || 
        key.toLowerCase().contains('mobile') ||
        key.toLowerCase().contains('website') ||
        key.toLowerCase().contains('function') ||
        key.toLowerCase().contains('job') ||
        key.toLowerCase().contains('title')
      ).toList();

      final fieldsToFetch = [
        'name',
        'email',
        'work_phone',
        'phone',
        'mobile',
        'work_mobile',
        'mobile_phone',
        'cell_phone',
        'personal_mobile',
        'website',
        'work_website',
        'website_url',
        'function',
        'job_title',
        'job_position',
        'position',
        'title',
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
        'company_id',
      ].where((field) => availableFields.containsKey(field)).toList();

      
      final userResponse = await client.callKw({
        'model': 'res.users',
        'method': 'read',
        'args': [[response.userId], fieldsToFetch],
        'kwargs': {},
      });

      Map<String, dynamic> userData = userResponse.isNotEmpty ? userResponse[0] : {};

      // Fetch partner data for phone field
      try {
        
        final partnerResponse = await client.callKw({
          'model': 'res.partner',
          'method': 'read',
          'args': [[updatedSession.partnerId], ['phone', 'mobile', 'website', 'function']],
          'kwargs': {},
        });
        
        if (partnerResponse.isNotEmpty) {
          final partnerData = partnerResponse[0];
          
          // Merge partner data into userData
          if (partnerData['phone'] != null && partnerData['phone'].toString().isNotEmpty) {
            userData['phone'] = partnerData['phone'];
          }
          if (partnerData['mobile'] != null && partnerData['mobile'].toString().isNotEmpty) {
            userData['partner_mobile'] = partnerData['mobile'];
          }
          if (partnerData['website'] != null && partnerData['website'].toString().isNotEmpty) {
            userData['partner_website'] = partnerData['website'];
          }
          if (partnerData['function'] != null && partnerData['function'].toString().isNotEmpty) {
            userData['partner_function'] = partnerData['function'];
          }
        }
      } catch (e) {
      }

      // Save to SharedPreferences and Isar
      await _saveUserData(prefs, updatedSession, userData, availableFields);
      await _saveSignedAccountToIsar(userData);
      await _saveSignedAccount(usernameController.text, widget.dbName);

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/webapp',
              (route) => false,
          arguments: {
            'serverUrl': widget.serverUrl,
            'dbName': widget.dbName,
            'username': usernameController.text,
            'password': passwordController.text,
            'sessionId': response.id,
          },
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      log('Add account error: $e');
      
      String errorMessage = 'Failed to add account. Please try again.';
      String errorString = e.toString().toLowerCase();
      
      if (errorString.contains('odoo session expired') ||
          errorString.contains('invalid username or password') ||
          errorString.contains('access denied') ||
          errorString.contains('wrong login/password') ||
          errorString.contains('authentication failed') ||
          errorString.contains('credential')) {
        errorMessage = 'Incorrect username or password';
      } else if (errorString.contains('connection') || 
                 errorString.contains('network') ||
                 errorString.contains('timeout')) {
        errorMessage = 'Connection error. Please check your network.';
      }
      
      // Clear session data if company ID mismatch or other critical error
      await prefs.remove('session_id');
      await prefs.remove('companyId');
      await prefs.remove('allowedCompanies');
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      client.close();
    }
  }

  /// Persists user and session data to SharedPreferences and Isar.
  Future<void> _saveUserData(
      SharedPreferences prefs,
      OdooSession session,
      Map<String, dynamic> userData,
      Map<String, dynamic> availableFields,
      ) async {
    // Save to SharedPreferences
    await prefs.setString("session_id", session.id);
    await prefs.setString("username", usernameController.text);
    await prefs.setString("password", passwordController.text);
    await prefs.setString("uri", widget.serverUrl);
    await prefs.setString("dbName", widget.dbName);
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
        "allowedCompanies",
        session.allowedCompanies.isNotEmpty
            ? session.allowedCompanies.toString()
            : '');

    // Save to Isar
    final isar = await IsarService.instance;
    final userProfile = UserProfile()
      ..userId = session.userId.toString()
      ..userName = availableFields.containsKey('name')
          ? (userData['name'] is String ? userData['name'] : session.userName)
          : session.userName
      ..userEmail = availableFields.containsKey('email')
          ? (userData['email'] is String ? userData['email'] : '')
          : ''
      ..userPhone = (userData['phone'] is String ? userData['phone'] : 
                   (userData['work_phone'] is String ? userData['work_phone'] : ''))
      ..userMobile = (userData['mobile'] is String ? userData['mobile'] : 
                    (userData['work_mobile'] is String ? userData['work_mobile'] : 
                     (userData['partner_mobile'] is String ? userData['partner_mobile'] : '')))
      ..userWebsite = (userData['website'] is String ? userData['website'] : 
                     (userData['work_website'] is String ? userData['work_website'] : 
                      (userData['partner_website'] is String ? userData['partner_website'] : '')))
      ..userFunction = (userData['function'] is String ? userData['function'] : 
                      (userData['job_title'] is String ? userData['job_title'] : 
                       (userData['partner_function'] is String ? userData['partner_function'] : '')))
      ..workLocation = availableFields.containsKey('work_location_id') &&
          userData['work_location_id'] is List &&
          userData['work_location_id'].isNotEmpty
          ? (userData['work_location_id'][1] is String
          ? userData['work_location_id'][1]
          : '')
          : ''
      ..department = availableFields.containsKey('department_id') &&
          userData['department_id'] is List &&
          userData['department_id'].isNotEmpty
          ? userData['department_id'][0].toString()
          : ''
      ..language = availableFields.containsKey('lang')
          ? (userData['lang'] is String ? userData['lang'] : '')
          : ''
      ..timezone = availableFields.containsKey('tz')
          ? (userData['tz'] is String ? userData['tz'] : '')
          : ''
      ..emailSignature = availableFields.containsKey('signature')
          ? (userData['signature'] is String ? userData['signature'] : '')
          : ''
      ..maritalStatus = availableFields.containsKey('marital')
          ? (userData['marital'] is String ? userData['marital'] : '')
          : ''
      ..profileImageBase64 = availableFields.containsKey('image_1920')
          ? (userData['image_1920'] is String ? userData['image_1920'] : '')
          : ''
      ..notificationByEmail = availableFields.containsKey('notification_type') &&
          userData['notification_type'] is String
          ? userData['notification_type'] == 'email'
          : false
      ..notificationInOdoo = availableFields.containsKey('notification_type') &&
          userData['notification_type'] is String
          ? userData['notification_type'] == 'inbox'
          : false
      ..odooBotStatus = availableFields.containsKey('odoobot_state') &&
          userData['odoobot_state'] is String
          ? userData['odoobot_state'] == 'onboarding' ||
          userData['odoobot_state'] == 'not_initialized'
          : false
      ..dbName = widget.dbName
      ..serverUrl = widget.serverUrl
      ..username = usernameController.text
      ..password = passwordController.text
      ..companyId = session.companyId.toString()
      ..accountKey = '${usernameController.text}@${widget.dbName}'
      ..lastUpdated = DateTime.now();

    await isar.writeTxn(() async {
      final existingProfile = await isar.userProfiles
          .filter()
          .accountKeyEqualTo(userProfile.accountKey!)
          .findFirst();
      if (existingProfile != null) userProfile.id = existingProfile.id;
      await isar.userProfiles.put(userProfile);
    });
  }

  /// Saves the current signed-in account details to the Isar database.
  Future<void> _saveSignedAccountToIsar(Map<String, dynamic> userData) async {
    final isar = await IsarService.instance;
    final accountKey = '${usernameController.text}@${widget.dbName}';
    
    // Extract image properly - handle both string and false values
    String profileImage = '';
    final imageData = userData['image_1920'];
    if (imageData != null && imageData != false && imageData is String && imageData.isNotEmpty) {
      profileImage = imageData;
    }
    
    // Extract user name properly
    String displayName = usernameController.text;
    final nameData = userData['name'];
    if (nameData != null && nameData != false && nameData is String && nameData.isNotEmpty) {
      displayName = nameData;
    }
    
    final signedAccount = SignedAccount()
      ..accountKey = accountKey
      ..username = usernameController.text
      ..serverAddress = widget.serverUrl
      ..database = widget.dbName
      ..password = passwordController.text
      ..userNameDisplay = displayName
      ..profileImage = profileImage
      ..accountIdentifier = accountKey;

    await isar.writeTxn(() async {
      final existingAccount = await isar.signedAccounts
          .where()
          .accountIdentifierEqualTo(accountKey)
          .findFirst();
      if (existingAccount != null) signedAccount.id = existingAccount.id;
      await isar.signedAccounts.put(signedAccount);
    });
    
  }

  Future<void> _saveSignedAccount(String username, String database) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accounts = prefs.getStringList('signed_accounts') ?? [];
    String account = '$username@$database';
    if (!accounts.contains(account) && username.isNotEmpty && database.isNotEmpty) {
      accounts.add(account);
      await prefs.setStringList('signed_accounts', accounts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Add Account',
      subtitle: 'Enter your credentials to add a new account',
      backButton: Positioned(
        top: 50,
        left: 16,
        child: IconButton(
          onPressed: () => Navigator.pop(context),
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
      child: _buildAddAccountForm(),
    );
  }

  Widget _buildAddAccountForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Username field
          LoginTextField(
            controller: usernameController,
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
            controller: passwordController,
            hint: 'Password',
            prefixIcon: HugeIcons.strokeRoundedLockPassword,
            focusNode: _passwordFocusNode,
            enabled: !_isLoading,
            obscureText: _obscureText,
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
                _obscureText
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
          
          // Error display
          LoginErrorDisplay(error: _errorMessage),
          
          // Add Account button
          LoginButton(
            text: 'Add Account',
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
                  'Adding Account...',
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
                _addAccount();
              }
            },
          ),
        ],
      ),
    );
  }
}