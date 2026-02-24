import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_pos/Loginpage/login.dart';
import 'package:mobo_pos/Loginpage/login_layout.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen for configuring the Odoo server URL and selecting the target database.
class ServerSetupScreen extends StatefulWidget {
  final OdooClient? client;
  const ServerSetupScreen({super.key, this.client});

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  
  String _selectedProtocol = 'https://';
  String? _selectedDatabase;
  List<String> _databases = [];
  List<String> _urlHistory = []; // Store previous URLs for suggestions
  bool _isLoading = false;
  bool _shouldValidate = false;
  bool _urlHasError = false;
  bool _dbHasError = false;
  String? _errorMessage;
  Timer? _debounceTimer;
  OdooClient? client;

  // Check if the Next button should be enabled
  bool get _isNextButtonEnabled {
    final hasUrl = _urlController.text.trim().isNotEmpty;
    final hasValidState = _databases.isEmpty || _selectedDatabase != null;
    return hasUrl && hasValidState && !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    client = widget.client;
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Load previously saved credentials and URL history
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('lastUrl');
    final savedDatabase = prefs.getString('lastDatabase');
    
    // Load URL history for suggestions
    final urlHistoryList = prefs.getStringList('urlHistory') ?? [];
    setState(() {
      _urlHistory = urlHistoryList;
    });
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
      // Extract protocol and clean URL
      String cleanUrl = savedUrl;
      if (savedUrl.startsWith('https://')) {
        _selectedProtocol = 'https://';
        cleanUrl = savedUrl.substring(8);
      } else if (savedUrl.startsWith('http://')) {
        _selectedProtocol = 'http://';
        cleanUrl = savedUrl.substring(7);
      }
      
      setState(() {
        _urlController.text = cleanUrl;
      });
      
      // Auto-fetch databases for saved URL
      _validateUrlAndFetchDatabases();
    }
    
    if (savedDatabase != null && savedDatabase.isNotEmpty) {
      setState(() {
        _selectedDatabase = savedDatabase;
      });
    }
  }

  // Set protocol
  void _setProtocol(String protocol) {
    setState(() {
      _selectedProtocol = protocol;
      // Clear databases when protocol changes
      _databases.clear();
      _selectedDatabase = null;
      _errorMessage = null;
    });
    // Re-fetch databases when protocol changes if URL is valid
    final trimmed = _urlController.text.trim();
    if (trimmed.isNotEmpty && _isValidUrl(trimmed)) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _validateUrlAndFetchDatabases();
        }
      });
    }
  }

  // Get full URL with protocol
  String _getFullUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return '';
    
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    return '$_selectedProtocol$url';
  }

  // Validate URL format
  bool _isValidUrl(String url) {
    try {
      String urlToValidate = url.trim();
      
      // Reject obviously incomplete URLs (single characters, too short, etc.)
      if (urlToValidate.length < 3) {
        return false;
      }
      
      if (!urlToValidate.startsWith('http://') && !urlToValidate.startsWith('https://')) {
        urlToValidate = '$_selectedProtocol$urlToValidate';
      }
      
      final uri = Uri.parse(urlToValidate);
      
      // Check if host is valid (not just a single character or empty)
      if (!uri.hasAuthority || uri.host.isEmpty || uri.host.length < 3) {
        return false;
      }
      
      // Check if host contains at least one dot (for domain.com format) or is localhost/IP
      if (!uri.host.contains('.') && 
          uri.host != 'localhost' && 
          !_isValidIP(uri.host)) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Check if string is a valid IP address
  bool _isValidIP(String host) {
    final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    return ipPattern.hasMatch(host);
  }

  // Normalize URL
  String _normalizeUrl(String url) {
    String normalizedUrl = url.trim();

    // Use the selected protocol from the dropdown
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = '$_selectedProtocol$normalizedUrl';
    }

    // Remove trailing slash
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }

    return normalizedUrl;
  }

  // Validate URL and fetch databases
  /// Validates the entered URL and fetches the list of available databases from the server.
  Future<void> _validateUrlAndFetchDatabases() async {
    final trimmedUrl = _urlController.text.trim();
    
    // If URL is empty or invalid, don't proceed
    if (trimmedUrl.isEmpty || !_isValidUrl(trimmedUrl)) {
      return;
    }

    if (!mounted) return;
    
    // Remember the currently selected database
    final currentSelectedDatabase = _selectedDatabase;
    
    // If we already have databases for this URL and a selected database, don't refetch
    if (_databases.isNotEmpty && client != null && currentSelectedDatabase != null) {
      // Just restore the selection without refetching
      setState(() {
        _selectedDatabase = currentSelectedDatabase;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _databases.clear();
      _selectedDatabase = null;
    });

    try {
      final baseUrl = _normalizeUrl(trimmedUrl);
      
      if (client == null || client!.baseURL != baseUrl) {
        client = OdooClient(baseUrl);
      } else {
      }
      
      final response = await client!
          .callRPC('/web/database/list', 'call', {})
          .timeout(const Duration(seconds: 15));
      
      
      if (response == null) {
        throw Exception('No response from server');
      }

      List<String> databases = [];
      
      // Handle different response formats from different Odoo versions
      if (response is List) {
        databases = response.cast<String>();
      } else if (response is Map && response.containsKey('result')) {
        final result = response['result'];
        if (result is List) {
          databases = result.cast<String>();
        }
      } else {
        // Fallback for other response formats
        databases = response.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      
      
      if (!mounted) return;
      
      // Save URL to history when successfully connected
      await _saveUrlToHistory(baseUrl);
      
      setState(() {
        _databases = databases;
        _isLoading = false;
        _shouldValidate = false;
        _urlHasError = false;
        _errorMessage = databases.isEmpty ? 'No databases found on this server.' : null;
      });
      
    } on SocketException catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      if (e.toString().contains('Network is unreachable')) {
        errorMessage = 'No internet connection. Please check your network settings and try again.';
      } else if (e.toString().contains('Connection refused')) {
        errorMessage = 'Server is not responding. Please verify the server URL and ensure the server is running.';
      } else {
        errorMessage = 'Network error occurred. Please check your internet connection and server URL.';
      }
      
      setState(() {
        _isLoading = false;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = errorMessage;
      });
    } on TimeoutException catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = 'Connection timed out. The server may be slow or unreachable. Please try again.';
      });
    } on OdooException catch (e) {
      if (!mounted) return;
      
      String errorMessage = _formatOdooError(e);
      
      setState(() {
        _isLoading = false;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = errorMessage;
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      if (e.toString().toLowerCase().contains('html')) {
        errorMessage = 'Invalid server response. This may not be an Odoo server or the URL path is incorrect.';
      } else {
        errorMessage = 'Server sent invalid data format. Please verify this is an Odoo server.';
      }
      
      setState(() {
        _isLoading = false;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = errorMessage;
      });
    } on HandshakeException catch (e) {
      if (!mounted) return;
      
      String errorMessage;
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED') || 
          e.toString().contains('unable to get local issuer certificate')) {
        errorMessage = 'SSL certificate verification failed. The server certificate is not trusted. Try using HTTP instead of HTTPS.';
      } else {
        errorMessage = 'SSL handshake failed. Try using HTTP instead of HTTPS or contact your administrator.';
      }
      
      setState(() {
        _isLoading = false;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = errorMessage;
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      
      final errorStr = e.toString().toLowerCase();
      String errorMessage;
      
      if (errorStr.contains('handshake')) {
        errorMessage = 'SSL connection failed. Try using HTTP instead of HTTPS or contact your administrator.';
      } else if (errorStr.contains('certificate')) {
        errorMessage = 'SSL certificate error. The server certificate may be invalid or expired. Try using HTTP instead.';
      } else if (errorStr.contains('host')) {
        errorMessage = 'Cannot reach server. Please check the server URL and your internet connection.';
      } else {
        errorMessage = 'Unable to connect to server. Please verify the server URL is correct.';
      }
      
      setState(() {
        _isLoading = false;
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = errorMessage;
      });
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

  // Handle database field animation when databases are fetched
  void _handleDatabaseAnimation() {
    // Animation removed - using simple show/hide logic
  }

  // Save URL to history when successfully connected
  Future<void> _saveUrlToHistory(String url) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];
    
    // Remove if already exists to avoid duplicates
    history.remove(url);
    
    // Add to beginning of list
    history.insert(0, url);
    
    // Keep only last 10 URLs
    if (history.length > 10) {
      history = history.take(10).toList();
    }
    
    await prefs.setStringList('urlHistory', history);
    
    setState(() {
      _urlHistory = history;
    });
  }

  // Proceed to login page
  /// Validates selections and navigates to the login screen.
  void _proceedToLogin() {
    if (_selectedDatabase == null || _selectedDatabase!.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a database';
      });
      return;
    }

    if (client == null) {
      setState(() {
        _errorMessage = 'Server connection not established. Please try again.';
      });
      return;
    }

    String url = _getFullUrl();

    // Save server details
    _saveServerDetails(url, _selectedDatabase!);

    // Navigate to login screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(
          serverUrl: url,
          database: _selectedDatabase!,
          client: client,
        ),
      ),
    );
  }

  // Save server details to SharedPreferences
  Future<void> _saveServerDetails(String url, String database) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uri', url);
    await prefs.setString('database', database);
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Sign In',
      subtitle: 'Configure your server connection',
      child: _buildServerSetupForm(),
    );
  }

  Widget _buildServerSetupForm() {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside fields
        FocusScope.of(context).unfocus();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Server URL input with protocol selection and URL suggestions
        LoginUrlTextField(
          controller: _urlController,
          hint: 'Enter Server Address',
          prefixIcon: HugeIcons.strokeRoundedServerStack01,
          enabled: true, // Always keep enabled so users can edit
          hasError: _urlHasError,
          selectedProtocol: _selectedProtocol,
          urlHistory: _urlHistory, // Pass URL history for suggestions
          isLoading: _isLoading, // Pass loading state to show loading indicator
          autovalidateMode: _shouldValidate
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (value) {
            if (_isLoading || !_shouldValidate) {
              return null;
            }
            if (value == null || value.isEmpty) {
              return 'Server URL is required';
            }
            return null;
          },
          onProtocolChanged: _setProtocol,
          onChanged: (value) {
            // Cancel previous timer
            _debounceTimer?.cancel();
            
            // Clear validation errors and databases when user starts typing
            setState(() {
              _shouldValidate = false;
              _urlHasError = false;
              _databases.clear(); // Clear databases when URL changes
              _selectedDatabase = null; // Clear selected database
              _errorMessage = null; // Clear any error messages
            });
            
            // Only start validation if URL is not empty
            final trimmed = value?.trim() ?? '';
            if (trimmed.isNotEmpty) {
              // Start debounce timer for network validation and database fetching
              _debounceTimer = Timer(const Duration(milliseconds: 1200), () {
                if (!mounted) return;
                _validateUrlAndFetchDatabases();
              });
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Show database dropdown if databases are available
        if (_databases.isNotEmpty) ...[
          const SizedBox(height: 6),
          LoginDropdownField(
            hint: _isLoading ? 'Loading...' : 'Database',
            value: _selectedDatabase,
            items: _databases,
            onChanged: _isLoading ? null : (String? newValue) {
              setState(() {
                _selectedDatabase = newValue;
                _dbHasError = (newValue == null || newValue.isEmpty);
                _errorMessage = null;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Database is required';
              }
              return null;
            },
            hasError: _dbHasError,
            autovalidateMode: _shouldValidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
          ),
        ],
        
        // Error display
        LoginErrorDisplay(error: _errorMessage),
        SizedBox(height: 32,),
        // Next button
        LoginButton(
          text: 'Next',
          isLoading: _isLoading,
          isEnabled: _isNextButtonEnabled,
          onPressed: _databases.isEmpty 
              ? () {
                  final trimmedUrl = _urlController.text.trim();
                  if (trimmedUrl.isEmpty) {
                    setState(() {
                      _shouldValidate = true;
                      _urlHasError = true;
                      _errorMessage = 'Server URL is required';
                    });
                    return;
                  }
                  
                  // Clear any validation errors and proceed
                  setState(() {
                    _shouldValidate = false;
                    _urlHasError = false;
                    _errorMessage = null;
                  });
                  _validateUrlAndFetchDatabases();
                }
              : (_selectedDatabase != null ? _proceedToLogin : () {
                  setState(() {
                    _shouldValidate = true;
                    _dbHasError = _selectedDatabase == null || _selectedDatabase!.isEmpty;
                    _errorMessage = 'Please select a database';
                  });
                }),
        ),
        ],
      ),
    );
  }
}
