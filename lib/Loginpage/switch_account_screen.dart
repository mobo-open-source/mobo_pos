import '../core/image_utils.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_layout.dart';
import 'two_factor_authentication.dart';
import '../services/auth_service.dart';
import '../services/pos_access_service.dart';
import '../services/storage_service.dart';
import '../services/network_service.dart';
import '../core/style.dart';
import '../ui/dialogs/app_dialogs.dart';

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
  // Tracks the background database-list fetch separately from _isLoading
  // (which governs account submission): the fetch reruns on every keystroke
  // via debounce, so tying the URL field's `enabled` to it would disable
  // (and kick the keyboard out of) the field mid-typing on every edit.
  bool _isFetchingDatabases = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  List<String> _databases = [];
  String? _selectedDatabase;
  final NetworkService _networkService = NetworkService();
  Timer? _debounce;
  String selectedProtocol = 'https://';
  int _currentStep = 0;
  String? _workingProtocol;
  String? _pendingProtocol;
  bool showError = false;
  List<String> _urlHistory = [];
  Map<String, Map<String, String>> _urlHistoryDetails = {};

  @override
  void initState() {
    super.initState();
    _loadUrlHistory();
    _initializeUrl();
    _urlController.addListener(_onUrlChanged);
  }

  /// Loads the shared `urlHistory` entries. Entries saved from this screen are
  /// JSON objects carrying the database/username/password alongside the URL
  /// (matching mobo FullSuite's `SwitchAccountScreen`); entries saved from
  /// [ServerSetupScreen]'s simpler flow are plain URL strings, so those are
  /// kept as-is with empty credential details.
  Future<void> _loadUrlHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList('urlHistory') ?? [];

    final urls = <String>[];
    final details = <String, Map<String, String>>{};

    for (final entry in rawHistory) {
      try {
        final decoded = jsonDecode(entry);
        final protocol = decoded['protocol'] ?? 'https://';
        final url = decoded['url'] ?? '';
        final fullUrl = '$protocol$url';
        urls.add(fullUrl);
        details[fullUrl] = {
          'db': decoded['db'] ?? '',
          'username': decoded['username'] ?? '',
          'password': decoded['password'] ?? '',
        };
      } catch (_) {
        if (entry.isNotEmpty) {
          urls.add(entry);
          details[entry] = {'db': '', 'username': '', 'password': ''};
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _urlHistory = urls.toSet().toList();
      _urlHistoryDetails = details;
    });
  }

  /// Saves a successfully-connected server, along with the database and
  /// credentials used, to the shared `urlHistory` list — most-recent-first,
  /// deduped by protocol+URL, matching mobo FullSuite's `SwitchAccountScreen`.
  Future<void> _saveUrlHistoryWithProtocol(
    String protocol,
    String url,
    String database,
    String username,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    final entry = {
      'protocol': protocol,
      'url': url,
      'db': database,
      'username': username,
      'password': password,
    };

    history.removeWhere((e) {
      try {
        final d = jsonDecode(e);
        return d['url'] == url && d['protocol'] == protocol;
      } catch (_) {
        return e == '$protocol$url';
      }
    });

    history.insert(0, jsonEncode(entry));
    await prefs.setStringList('urlHistory', history);
    await _loadUrlHistory();
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
    final pendingProtocol = _pendingProtocol;
    if (pendingProtocol != null) {
      _pendingProtocol = null;
      if (selectedProtocol != pendingProtocol) {
        setState(() {
          selectedProtocol = pendingProtocol;
        });
      }
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // _fetchDatabaseList() is the only place that resets the error/database
    // state, but it's only called below when the field is non-empty - so
    // clearing the field back to empty (e.g. deleting a URL that failed to
    // validate) used to leave the stale error showing forever, since nothing
    // else ever ran to clear it. Reset immediately on every change instead,
    // matching ServerSetupScreen's equivalent onChanged handler.
    setState(() {
      _databases.clear();
      _selectedDatabase = null;
      _errorMessage = null;
      _workingProtocol = null;
      showError = false;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_urlController.text.isNotEmpty) {
        _fetchDatabaseList();
      }
    });
  }

  /// Restores the database/username/password saved alongside a tapped URL
  /// suggestion, matching mobo FullSuite's autofill-from-history behavior.
  void _onHistorySelected(String selectedUrl) {
    final entry = _urlHistoryDetails[selectedUrl];
    if (entry == null) return;
    setState(() {
      if ((entry['db'] ?? '').isNotEmpty) {
        _selectedDatabase = entry['db'];
      }
      _usernameController.text = entry['username'] ?? '';
      _passwordController.text = entry['password'] ?? '';
    });
  }

  /// Fetches the list of databases for the current URL.
  Future<void> _fetchDatabaseList() async {
    try {
      setState(() {
        _isFetchingDatabases = true;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = null;
        _workingProtocol = null;
        showError = false;
      });

      String rawUrl = _urlController.text.trim();
      final match = RegExp(
        r'^(https?://)',
        caseSensitive: false,
      ).firstMatch(rawUrl);

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
          final dbList = await _networkService.fetchDatabaseList(
            '$protocol$host',
          );

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
        _isFetchingDatabases = false;
      });
    }
  }

  String _formatLoginError(dynamic error) =>
      AuthService.formatLoginError(error);

  /// Shown when [PosAccessService.checkAccess] rejects the account being
  /// added, using the same copy as [BackendPage]'s equivalent dialogs — but
  /// (unlike there) nothing was ever saved for this account, so there's
  /// nothing to log out of.
  Future<void> _showPosAccessDialog(PosAccessStatus status) async {
    if (status == PosAccessStatus.ok) return;

    if (status == PosAccessStatus.moduleNotInstalled) {
      // Matches BackendPage's post-login "Module Missing" dialog for the
      // same failure — a single acknowledgement button rather than an
      // OK/Back choice. "Back to Login" returns to this same Add Account
      // flow's first step (server + database), the same as tapping the
      // screen's own back arrow from the credentials step — not the plain
      // login page, since nothing was ever saved for this account and
      // there's another already-signed-in account this flow was reached
      // from.
      await AppDialogs.showModuleMissing(
        context,
        title: 'Module Missing',
        message:
            'The required "Point of Sale" module is not installed on this '
            'server. Please contact your administrator to enable it.',
        buttonText: 'Back to Login',
      );
      if (mounted) {
        setState(() {
          _currentStep = 0;
        });
      }
      return;
    }

    late final String title;
    late final String message;
    if (status == PosAccessStatus.accessDenied) {
      title = 'Access Denied';
      message =
          "Your account doesn't have permission to access Point of Sale. "
          "Please contact your Odoo administrator to be added to the "
          "Point of Sale / User or Point of Sale / Administrator group.";
    } else {
      title = 'Configuration Required';
      message =
          "Please enable the 'Show in POS Mobile' field in POS settings.";
    }

    // "OK" stays on this screen to retry with different credentials; "Back"
    // leaves the Add Account flow entirely, returning to whichever screen
    // opened it.
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: title,
      message: message,
      confirmText: 'OK',
      cancelText: 'Back',
    );
    if (confirmed != true && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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

  /// Authenticates the user and adds the new account to the local storage.
  Future<void> _addAccount() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final url =
          '${_workingProtocol ?? selectedProtocol}${_urlController.text.trim()}';
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

      final client = OdooClient(url);
      await client.authenticate(
        dbName,
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      // Verify this account can actually use POS before treating it as the
      // active session. An account that fails this check must never be
      // logged in at all — nothing has been saved yet at this point, so on
      // failure the user just stays on this screen with whatever account
      // was active before untouched, free to try different credentials,
      // instead of being bounced through a login/logout cycle.
      final accessResult = await PosAccessService.checkAccess(client);
      if (accessResult.status != PosAccessStatus.ok) {
        client.close();
        if (mounted) {
          await _showPosAccessDialog(accessResult.status);
        }
        return;
      }

      final storageService = StorageService();
      await storageService.saveSession(session);
      await storageService.saveLoginState(
        isLoggedIn: true,
        database: dbName,
        url: url,
        password: _passwordController.text.trim(),
      );

      Map<String, dynamic> availableFields = {};
      try {
        final fieldsResponse = await client.callKw({
          'model': 'res.users',
          'method': 'fields_get',
          'args': [],
          'kwargs': {
            'attributes': ['type', 'selection'],
          },
        });
        availableFields = fieldsResponse as Map<String, dynamic>;
      } catch (e) {}

      final fieldsToFetch =
          [
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
              fieldsToFetch,
            ],
            'kwargs': {},
          });
          userData = userResponse.isNotEmpty ? userResponse[0] : {};
        } catch (e) {}
      }

      await AuthService().saveAuthenticatedSession(
        url: url,
        database: dbName,
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        sessionId: session.id,
        userId: session.userId,
        userLogin: session.userLogin,
        userName:
            (userData['name'] is String &&
                    (userData['name'] as String).isNotEmpty)
                ? userData['name'] as String
                : session.userName,
        partnerId: session.partnerId,
        userLang: session.userLang,
        userTz: session.userTz,
        isSystem: session.isSystem,
        serverVersion: session.serverVersion,
        companyId: session.companyId,
        imageBase64:
            ImageUtils.base64Of(userData['image_1920']),
      );

      await _saveUrlHistoryWithProtocol(
        _workingProtocol ?? selectedProtocol,
        _urlController.text.trim(),
        dbName,
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/backend');
      }
    } catch (e) {
      final formatted = _formatLoginError(e);
      if (formatted == AuthService.genericSwitchAccountFailureMessage) {
        // Unrecognized failure, being treated as "this account likely has
        // 2FA enabled" — a heuristic guess, not a real check. Log the raw
        // error so a false positive can be diagnosed instead of silently
        // masked by the 2FA screen.
        debugPrint(
          'AddAccount: unrecognized failure, assuming 2FA — raw error: $e',
        );
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        final url =
            '${_workingProtocol ?? selectedProtocol}${_urlController.text.trim()}';
        final dbName = _selectedDatabase ?? '';
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder:
                (_) => TwoFactorAuthPage(
                  serverUrl: url,
                  database: dbName,
                  username: _usernameController.text.trim(),
                  password: _passwordController.text.trim(),
                  onSuccessRouteName: '/backend',
                ),
          ),
        );
        if (result == false) {
          setState(() {
            _errorMessage = null;
          });
        }
        return;
      }
      if (e.toString().toLowerCase().contains('runbot')) {
        // A Runbot test server blocking this database from the caller's
        // network location — an external access restriction. Show it as a
        // popup rather than inline text, matching how the same case is
        // presented once already logged in (BackendPage's alerts). "OK"
        // stays on this screen to try different credentials; "Back" leaves
        // the Add Account flow entirely, same as the POS-access dialog.
        setState(() => _isLoading = false);
        if (mounted) {
          final confirmed = await AppDialogs.showConfirm(
            context,
            title: 'Server Not Accessible',
            message: formatted,
            confirmText: 'OK',
            cancelText: 'Back',
          );
          if (confirmed != true && mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
        return;
      }
      setState(() {
        _errorMessage = formatted;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                  onTap:
                      _isLoading
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
                      FittedBox(
                        child: Text(
                          "Add Account",
                          style: GoogleFonts.montserrat(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
                                LoginUrlTextField(
                                  controller: _urlController,
                                  hint: 'Enter Server Address',
                                  prefixIcon:
                                      HugeIcons.strokeRoundedServerStack01,
                                  enabled: !_isLoading,
                                  isLoading: _isFetchingDatabases,
                                  selectedProtocol: selectedProtocol,
                                  urlHistory: _urlHistory,
                                  onProtocolChanged: (value) {
                                    setState(() {
                                      selectedProtocol = value;
                                    });
                                    _fetchDatabaseList();
                                  },
                                  onProtocolDetected: (protocol) {
                                    _pendingProtocol = protocol;
                                  },
                                  onHistorySelected: _onHistorySelected,
                                  onChanged: (_) {},
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Server URL is required';
                                    }
                                    return null;
                                  },
                                  hasError: showError,
                                ),
                                const SizedBox(height: 20),
                                if (_databases.isNotEmpty) ...[
                                  LoginDropdownField(
                                    hint: 'Select Database',
                                    value: _selectedDatabase,
                                    items: _databases,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDatabase = value;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a database';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ] else ...[
                                LoginTextField(
                                  controller: _usernameController,
                                  hint: 'Username',
                                  prefixIcon: HugeIcons.strokeRoundedUser03,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Username is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                LoginTextField(
                                  controller: _passwordController,
                                  hint: 'Password',
                                  obscureText: !_isPasswordVisible,
                                  prefixIcon:
                                      HugeIcons.strokeRoundedSquareLockPassword,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Password is required';
                                    }
                                    return null;
                                  },
                                  suffixIcon: IconButton(
                                    icon: HugeIcon(
                                      icon:
                                          _isPasswordVisible
                                              ? HugeIcons.strokeRoundedView
                                              : HugeIcons.strokeRoundedViewOff,
                                      color:
                                          _isPasswordVisible
                                              ? Colors.black26
                                              : Colors.black54,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
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
                            // Colors.red reads as a muted, low-contrast
                            // reddish-brown against this screen's dark
                            // maroon/pink background. Matches the mobo CRM
                            // app's equivalent screen (server_url_screen.dart)
                            // and this app's own LoginErrorDisplay widget,
                            // both of which use plain white here.
                            style: AppStyle.font(color: Colors.white),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : () {
                                    if (_currentStep == 0) {
                                      if (_loginFormKey.currentState!
                                          .validate()) {
                                        if (_isFetchingDatabases) {
                                          setState(() {
                                            _errorMessage =
                                                "Please wait while the server is being verified...";
                                          });
                                          return;
                                        }
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
                          child:
                              _isLoading
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
}
