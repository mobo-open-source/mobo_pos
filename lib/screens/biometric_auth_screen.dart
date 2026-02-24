import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:logging/logging.dart';
import '../services/biometric_service.dart';

class BiometricAuthScreen extends StatefulWidget {
  final VoidCallback? onAuthenticationSuccess;
  final bool useStandardFonts;
  
  const BiometricAuthScreen({
    super.key,
    this.onAuthenticationSuccess,
    this.useStandardFonts = false,
  });

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  final Logger _logger = Logger('BiometricAuthScreen');
  
  bool _isAuthenticating = false;
  bool _authenticationFailed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _logger.info('🔄 BiometricAuthScreen initialized');
    // Authenticate immediately like sales_app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performAuthentication();
    });
  }

  Future<void> _performAuthentication() async {
    if (_isAuthenticating) return;

    _logger.info('Starting authentication process...');
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await BiometricService.authenticateWithBiometrics(
          reason: 'Please authenticate to access the MOBO POS App');

      _logger.info('Authentication result: $success');
      
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
        
        if (success) {
          _logger.info('✅ Authentication successful');
          setState(() {
            _authenticationFailed = false;
            _errorMessage = null;
          });
          
          // Call the callback to notify parent widget
          widget.onAuthenticationSuccess?.call();
        } else {
          _logger.warning('❌ Authentication failed');
          setState(() {
            _authenticationFailed = true;
            _errorMessage = 'Authentication failed or was cancelled';
          });
        }
      } else {
        _logger.warning('Widget not mounted after authentication');
      }
    } catch (e) {
      _logger.severe('Authentication error: $e');
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _authenticationFailed = true;
          _errorMessage = 'Unexpected authentication error';
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
          // Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage('assets/loginbg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? Colors.black.withOpacity(1)
                        : Colors.white.withOpacity(1),
                    BlendMode.dstATop,
                  ),
                  onError: (exception, stackTrace) {
                    // Fallback to solid color if image fails to load
                  },
                ),
              ),
            ),
          ),

          // Main content
          LayoutBuilder(
            builder: (context, viewportConstraints) {
              return Column(
                children: [
                  // App name and logo at the top
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 68),
                      child: _buildAppHeader(),
                    ),
                  ),
                  
                  // Scrollable content area for authentication
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: viewportConstraints.maxHeight - 180, // Account for header height
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Authentication header
                                  _buildAuthHeader(),
                                  const SizedBox(height: 24),

                                  // Authentication content
                                  if (_isAuthenticating)
                                    _buildAuthenticatingDisplay()
                                  else if (_authenticationFailed)
                                    _buildRetryButton()
                                  else
                                    _buildInitialDisplay(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // Build app header (POS App + logo at top)
  Widget _buildAppHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/pos-icon.png',
          width: 32,
          height: 32,
          fit: BoxFit.fitWidth,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.business,
              color: Color(0xFFC03355),
              size: 24,
            );
          },
        ),
        const SizedBox(width: 12),
        Text(
          'mobo POS',
          style: const TextStyle(
            fontFamily: 'YaroRg',
            color: Colors.white,
            fontSize: 24,
          ),
        ),
      ],
    );
  }

  // Build authentication header (centered)
  Widget _buildAuthHeader() {
    return Column(
      children: [
        // "App Locked" text
        Text(
          'App Locked',
          style: widget.useStandardFonts
              ? const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 22)
              : GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 22,
                ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        
        // Subtitle text
        Text(
          'Please authenticate to continue',
          style: widget.useStandardFonts
              ? const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400)
              : GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  
  Widget _buildAuthenticatingDisplay() {
    return Column(
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Authenticating...',
          style: widget.useStandardFonts
              ? const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)
              : GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
        ),
      ],
    );
  }
  
  Widget _buildRetryButton() {
    return Column(
      children: [
        if (_errorMessage != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HugeIcon(icon:HugeIcons.strokeRoundedAlertCircle,
                  color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          height: 48,
          width: MediaQuery.of(context).size.width*.7,
          child: ElevatedButton(
            onPressed: () {
              _logger.info('🔘 Retry authentication button pressed');
              setState(() {
                _authenticationFailed = false;
                _errorMessage = null;
              });
              _performAuthentication();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black.withOpacity(.2),
              disabledForegroundColor: Colors.white,
              overlayColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: widget.useStandardFonts
                  ? const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
                  : GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInitialDisplay() {
    return Column(
      children: [
        Icon(
          Icons.fingerprint,
          size: 48,
          color: Colors.white.withOpacity(0.8),
        ),
        const SizedBox(height: 16),
        Text(
          'Touch sensor or use face unlock',
          style: widget.useStandardFonts
              ? const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400)
              : GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
}
