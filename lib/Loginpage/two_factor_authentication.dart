import '../services/database_expiry.dart';
import '../core/image_utils.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/colors/app_colors.dart';
import '../core/two_factor_auth.dart';
import '../core/utils/odoo_url.dart';
import '../services/auth_service.dart';

/// Two-factor (TOTP) authentication step, reached when a login attempt's
/// error can't be explained by any recognized failure (bad credentials,
/// unreachable server, missing database, ...) — the same heuristic mobo
/// FullSuite uses to infer that the account has TOTP enabled.
///
/// This is not a REST/RPC call: Odoo doesn't expose a native TOTP API. It
/// drives an invisible WebView through Odoo's own server-rendered
/// `/web/login` -> `/web/login/totp` pages exactly as a browser would —
/// filling the real login form via injected JS, then letting the user type
/// their 6-digit code into a single visible field, injecting that into the
/// real `input[name="totp_token"]`, and submitting it.
class TwoFactorAuthPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;

  /// Named route pushed (clearing the stack) once the session is verified
  /// and saved. Callers that land in different post-login destinations
  /// (direct login vs. add/switch account) pass their own target here.
  final String onSuccessRouteName;

  const TwoFactorAuthPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    this.onSuccessRouteName = '/backend',
  });

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  InAppWebViewController? _webController;
  final _totpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _error;
  bool _loading = true;
  bool _verifying = false;
  bool _isButtonEnabled = false;
  bool _credentialsInjected = false;
  bool _isAuthenticating = false;
  bool _totpPageSeen = false;
  String? _sessionId;

  // Odoo only renders the TOTP challenge while the partial-auth session
  // (`session.pre_uid`) it set during the credentials POST is still present;
  // if that session state didn't carry over to the follow-up GET for any
  // reason, `/web/login/totp` silently redirects back to the plain
  // `/web/login` form instead. When that happens the TOTP field can never be
  // found no matter how long `_submitTotp` retries, because it's polling the
  // wrong page. This recovers once by re-submitting the credentials and
  // retrying the same code automatically, instead of failing outright.
  bool _recoveredFromBounce = false;

  Timer? _autoLoginWatchdog;
  static const Duration _autoLoginTimeout = Duration(seconds: 25);

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  String get _serverUrl {
    final u = widget.serverUrl;
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  @override
  void dispose() {
    if (TwoFactorAuth.activeServer == _serverUrl) {
      TwoFactorAuth.activeServer = null;
    }
    _autoLoginWatchdog?.cancel();
    _totpController.dispose();
    _webController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isAuthenticating && Navigator.of(context).canPop(),
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _exitTwoFactorFlow();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage('assets/loginbg.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark ? Colors.black : Colors.white,
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.0,
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri('about:blank')),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      cacheEnabled: false,
                      clearCache: true,
                      // Mobile agents get a layout without `.o_web_client`,
                      // so sign-in detection never fires.
                      userAgent: _desktopUserAgent,
                      useHybridComposition: true,
                      allowContentAccess: true,
                      allowFileAccess: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                      disableDefaultErrorPage: true,
                    ),
                    onWebViewCreated: (controller) async {
                      _webController = controller;
                      final activePrefs = await SharedPreferences.getInstance();
                      final activeUri = activePrefs.getString('uri');
                      if (activeUri != null && activeUri == _serverUrl) {
                        // This 2FA flow is for the account whose session the
                        // main webview is currently (or was just) serving —
                        // guard it from touching cookies/attempting its own
                        // silent relogin for this server while this flow is
                        // in progress.
                        TwoFactorAuth.activeServer = _serverUrl;
                      }
                      // Clear every cookie for this domain (not just
                      // session_id) plus cache/localStorage so a prior
                      // successful login on this device can't leak stale
                      // state into this fresh attempt.
                      await CookieManager.instance().deleteCookies(
                        url: WebUri(_serverUrl),
                      );
                      await InAppWebViewController.clearAllCache();
                      await WebStorageManager.instance().deleteAllData();
                      await controller.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(
                            '$_serverUrl/web/login?db=${widget.database}',
                          ),
                        ),
                      );
                    },
                    onReceivedServerTrustAuthRequest:
                        (controller, challenge) async =>
                            ServerTrustAuthResponse(
                              action: ServerTrustAuthResponseAction.PROCEED,
                            ),
                    onReceivedError: (controller, request, error) {
                      if (!mounted || _isAuthenticating) return;
                      setState(() {
                        _loading = false;
                        _error = 'Failed to load: ${error.description}';
                      });
                    },
                    onLoadStop: (controller, url) async {
                      final urlStr = url?.toString() ?? '';
                      if (urlStr == 'about:blank' || _isAuthenticating) return;

                      if (isOdooDatabaseSelectorUrl(urlStr)) {
                        await _handleDatabaseSelector();
                        return;
                      }

                      if (isOdooTotpUrl(urlStr)) {
                        _totpPageSeen = true;
                        _autoLoginWatchdog?.cancel();
                        if (mounted) setState(() => _loading = false);
                        return;
                      }

                      if (isOdooLoginUrl(urlStr)) {
                        // A rejected TOTP code also lands back here — that is
                        // NOT treated as failure by itself; _submitTotp's own
                        // DOM polling (.alert-danger / success markers) is
                        // the sole authority on success/failure. But if we
                        // land here BEFORE the TOTP page was ever reached,
                        // this is the initial credential injection being
                        // rejected outright (wrong username/password).
                        if (_credentialsInjected) {
                          if (!_totpPageSeen && !_isAuthenticating && mounted) {
                            final rejected = await _webController
                                ?.evaluateJavascript(
                                  source: """
                              (function() {
                                return !!document.querySelector('.alert-danger, .o_error_dialog');
                              })();
                            """,
                                );
                            if (rejected == true &&
                                mounted &&
                                !_isAuthenticating) {
                              _autoLoginWatchdog?.cancel();
                              setState(() {
                                _loading = false;
                                _error =
                                    'Invalid username or password. '
                                    'Please check your credentials.';
                              });
                            }
                          }
                          return;
                        }
                        _startAutoLoginWatchdog();
                        await _injectCredentialsWhenReady();
                        return;
                      }

                      if (isOdooBackendUrl(urlStr)) {
                        await _completeIfSignedIn();
                      }
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                bottom: false,
                child: IgnorePointer(
                  ignoring: _isAuthenticating,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _exitTwoFactorFlow,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        height: 64,
                        width: 64,
                        alignment: Alignment.center,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color:
                              _isAuthenticating ? Colors.white54 : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              Container(
                color: Colors.white70,
                child: Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: AppColors.primary,
                    size: 60,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To login, enter below the six-digit authentication code provided '
          'by your Authenticator app.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_loading && !_verifying,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(0.4),
              ),
              prefixIcon: const SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSmsCode,
                    color: Colors.black54,
                    size: 20,
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child:
                _error != null
                    ? Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedAlertCircle,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.manrope(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _verifying
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Authenticating',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                        'Authenticate',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  void _startAutoLoginWatchdog() {
    _autoLoginWatchdog?.cancel();
    _autoLoginWatchdog = Timer(_autoLoginTimeout, () {
      if (!mounted || _isAuthenticating) return;
      setState(() {
        _loading = false;
        _error =
            'Could not sign in automatically. Check your credentials '
            'and try again.';
      });
    });
  }

  Future<void> _handleDatabaseSelector() async {
    final db = jsonEncode(widget.database);
    await _webController?.evaluateJavascript(
      source: """
      (function() {
        var select = document.querySelector('select[name="db"]');
        if (select) {
          select.value = $db;
          var btn = document.querySelector('button[type="submit"]');
          if (btn) btn.click();
        }
      })();
    """,
    );
  }

  Future<bool> _injectCredentials() async {
    if (_credentialsInjected) return true;

    final safeUser = jsonEncode(widget.username);
    final safePass = jsonEncode(widget.password);
    final safeDb = jsonEncode(widget.database);

    try {
      final result = await _webController?.evaluateJavascript(
        source: """
        (function() {
          var login = document.querySelector('input[name="login"], input[type="email"]');
          var password = document.querySelector('input[name="password"]');
          var db = document.querySelector('input[name="db"], select[name="db"]');
          var form = document.querySelector('form[action*="/web/login"]');

          if (!login || !password || !form) return false;

          login.value = $safeUser;
          password.value = $safePass;
          if (db) db.value = $safeDb;

          var btn = form.querySelector('button[type="submit"]');
          if (btn) btn.click();
          else form.submit();
          return true;
        })();
      """,
      );

      final ok = result == true || result == 1 || result == 'true';
      if (ok) _credentialsInjected = true;
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _injectCredentialsWhenReady() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted || _isAuthenticating || _credentialsInjected) return;
      if (await _injectCredentials()) return;
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> _submitTotp({bool isAutoRetry = false}) async {
    if (!isAutoRetry) {
      if (!(_formKey.currentState?.validate() ?? false)) return;

      final entered = _totpController.text.trim();
      if (entered.length != 6 || !RegExp(r'^\d{6}$').hasMatch(entered)) {
        setState(() => _error = 'Please enter a valid 6-digit code');
        return;
      }

      setState(() {
        _verifying = true;
        _error = null;
      });
    }

    final totp = _totpController.text.trim();
    final safeTotp = jsonEncode(totp);
    try {
      var marker = 'totp_input_not_found';
      for (var attempt = 0; attempt < 20; attempt++) {
        if (!mounted || _isAuthenticating) return;
        final submitResult = await _webController?.evaluateJavascript(
          source: """
          (function() {
            var input = document.querySelector(
              'input[name="totp_token"], input[autocomplete="one-time-code"], input[type="text"][maxlength="6"], input[type="number"][maxlength="6"]'
            );

            // Fallback for servers whose TOTP/2FA page markup doesn't match
            // stock Odoo's auth_totp template exactly (custom themes,
            // auth_totp_mail's email-code variant, older/newer versions):
            // fall back to the sole visible, interactive input on the page,
            // preferring one whose name/id/placeholder hints at a code field.
            if (!input) {
              var candidates = Array.prototype.filter.call(
                document.querySelectorAll('input'),
                function(el) {
                  var type = (el.type || 'text').toLowerCase();
                  if (['hidden', 'checkbox', 'radio', 'submit', 'button', 'file'].indexOf(type) !== -1) return false;
                  var rect = el.getBoundingClientRect();
                  return rect.width > 0 && rect.height > 0;
                }
              );
              if (candidates.length === 1) {
                input = candidates[0];
              } else if (candidates.length > 1) {
                input = candidates.filter(function(el) {
                  var hay = ((el.name || '') + ' ' + (el.id || '') + ' ' + (el.placeholder || '')).toLowerCase();
                  return hay.indexOf('totp') !== -1 || hay.indexOf('code') !== -1 ||
                    hay.indexOf('token') !== -1 || hay.indexOf('otp') !== -1;
                })[0] || candidates[0];
              }
            }

            if (!input) return "totp_input_not_found";

            input.focus();
            input.value = $safeTotp;
            ['input', 'change', 'keydown', 'keyup', 'keypress'].forEach(function(t) {
              input.dispatchEvent(new KeyboardEvent(t, {key: 'Enter', bubbles: true, cancelable: true}));
            });

            // Odoo's actual field for this is name="remember" (auth_totp's
            // own template) — checking it lets Odoo set a trusted-device
            // cookie so future logins on this device skip the TOTP step.
            var trust = document.querySelector('input[name="remember"], input[name="trust_device"], [name="trust"]');
            if (trust && !trust.checked) {
              trust.checked = true;
              trust.dispatchEvent(new Event('change', {bubbles: true}));
            }

            var form = input.closest('form') || document.querySelector('form[action*="/web/login"]');
            if (!form) return "form_not_found";
            var btn = form.querySelector('button[type="submit"]') ||
              form.querySelector('button[name="submit"]') ||
              form.querySelector('button.btn-primary') ||
              form.querySelector('button.btn-block') ||
              form.querySelector('input[type="submit"]') ||
              form.querySelector('button:not([type="button"])');
            if (btn) btn.click();
            else form.submit();
            return "totp_submitted";
          })();
        """,
        );

        marker = submitResult?.toString() ?? 'totp_input_not_found';
        if (marker != 'totp_input_not_found' && marker != 'form_not_found') {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (marker == 'totp_input_not_found' || marker == 'form_not_found') {
        // The TOTP field can be legitimately absent for a reason other than
        // "wrong page markup": Odoo only renders the TOTP challenge while
        // the partial-auth session it set during the credentials POST is
        // still present server-side; if that state didn't carry over, GET
        // /web/login/totp silently redirects back to the plain /web/login
        // form instead of erroring. Detect that specific case (the page now
        // has a password field) and recover by re-submitting the
        // credentials once, then retrying this same code automatically —
        // rather than surfacing a confusing "could not submit" to the user
        // for something that isn't actually about the code they typed.
        if (!_recoveredFromBounce && !_isAuthenticating && mounted) {
          final onLoginPage = await _webController?.evaluateJavascript(
            source: """
            (function() {
              return !!document.querySelector('input[name="password"]');
            })();
          """,
          );
          if (onLoginPage == true && !_isAuthenticating && mounted) {
            _recoveredFromBounce = true;
            _credentialsInjected = false;
            _totpPageSeen = false;
            setState(() => _loading = true);
            await _injectCredentialsWhenReady();
            for (var i = 0; i < 20; i++) {
              await Future.delayed(const Duration(milliseconds: 300));
              if (!mounted || _isAuthenticating) return;
              if (_totpPageSeen) break;
            }
            if (!mounted || _isAuthenticating) return;
            if (_totpPageSeen) {
              return _submitTotp(isAutoRetry: true);
            }
          }
        }
        if (mounted) {
          setState(() {
            _loading = false;
            _verifying = false;
            _totpController.clear();
            _isButtonEnabled = false;
            _error =
                'Could not submit the code on this server. '
                'Please try again.';
          });
        }
        return;
      }

      await Future.delayed(const Duration(seconds: 2));

      for (var i = 0; i < 24; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted || _isAuthenticating) return;

        final state = await _webController?.evaluateJavascript(
          source: """
          (function() {
            if (document.querySelector('.o_user_menu, .oe_topbar_avatar, .o_apps_switcher, [data-menu="account"], .o_web_client, .o_action_manager')) return 'ok';
            if (document.querySelector('.alert-danger, .o_error_dialog')) return 'error';
            return 'wait';
          })();
        """,
        );

        if (state == 'error') {
          setState(() {
            _verifying = false;
            _error = 'Invalid code or login failed. Please try again.';
          });
          return;
        }
        if (state != 'ok') {
          final currentUrl = (await _webController?.getUrl())?.toString() ?? '';
          if (isOdooBackendUrl(currentUrl)) {
            await _completeIfSignedIn();
            return;
          }
        }
        if (state == 'ok') {
          await _completeIfSignedIn();
          return;
        }
      }

      // A slow web client is not proof of failure; _saveSessionData still
      // validates the session server-side.
      await _completeIfSignedIn();

      if (mounted && !_isAuthenticating && _error == null) {
        setState(() {
          _verifying = false;
          _error = 'Verification timed out. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = 'Could not verify the code. Please try again.';
        });
      }
    }
  }

  Future<void> _completeIfSignedIn() async {
    if (_isAuthenticating || !mounted) return;

    // Odoo hands an anonymous `session_id` to every visitor, so a cookie
    // alone proves nothing — require the web client or a backend page.
    final domSuccess = await _webController?.evaluateJavascript(
      source: """
      (function() {
        return !!document.querySelector('.o_user_menu, .oe_topbar_avatar, .o_web_client, .o_action_manager');
      })();
    """,
    );
    final currentUrl = (await _webController?.getUrl())?.toString() ?? '';
    final signedIn = domSuccess == true || isOdooBackendUrl(currentUrl);
    if (!signedIn) return;

    final sessionCookie = await _readSessionCookie();
    if (sessionCookie.isEmpty) return;

    _sessionId = sessionCookie;
    setState(() {
      _isAuthenticating = true;
      _verifying = true;
    });
    final sessionInfo = await _readSessionInfoFromPage();
    await _saveSessionData(sessionInfo: sessionInfo);
  }

  /// Reads Odoo's own `odoo.session_info` global straight from the
  /// already-signed-in page's JS context — the exact identity data Odoo used
  /// to render the web client, needing no separate network call.
  Future<Map<String, dynamic>?> _readSessionInfoFromPage() async {
    try {
      final result = await _webController?.evaluateJavascript(
        source: """
        (function () {
          return (typeof odoo !== 'undefined' && odoo.session_info)
            ? odoo.session_info
            : null;
        })();
      """,
      );
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}
    return null;
  }

  Future<String> _readSessionCookie() async {
    final candidates = <WebUri>[];
    try {
      final current = await _webController?.getUrl();
      if (current != null) candidates.add(current);
    } catch (_) {}
    candidates.add(WebUri(_serverUrl));

    for (final url in candidates) {
      try {
        final cookies = await CookieManager.instance().getCookies(url: url);
        for (final c in cookies) {
          if (c.name == 'session_id' && c.value.toString().isNotEmpty) {
            return c.value.toString();
          }
        }
      } catch (_) {}
    }
    return '';
  }

  Future<void> _exitTwoFactorFlow() async {
    if (_isAuthenticating || !mounted) return;

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('session_id');

    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _saveSessionData({Map<String, dynamic>? sessionInfo}) async {
    try {
      if (_sessionId == null || _sessionId!.isEmpty) {
        final cookies = await CookieManager.instance().getCookies(
          url: WebUri(_serverUrl),
        );
        final sessionCookie = cookies.firstWhere(
          (cookie) => cookie.name == 'session_id',
          orElse: () => Cookie(name: '', value: ''),
        );
        if (sessionCookie.value.isEmpty) {
          throw Exception('Session cookie not found');
        }
        _sessionId = sessionCookie.value;
      }

      Map<String, dynamic>? sessionResult;
      var sessionRejected = false;

      if (sessionInfo != null &&
          sessionInfo['uid'] != false &&
          sessionInfo['uid'] != null) {
        sessionResult = sessionInfo;
      } else {
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            final infoResponse = await http
                .post(
                  Uri.parse('$_serverUrl/web/session/get_session_info'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-Requested-With': 'XMLHttpRequest',
                    'User-Agent': _desktopUserAgent,
                    'Origin': _serverUrl,
                    'Referer': '$_serverUrl/web',
                    'Cookie': 'session_id=${_sessionId!}',
                  },
                  body: jsonEncode({
                    'jsonrpc': '2.0',
                    'method': 'call',
                    'params': {},
                  }),
                )
                .timeout(const Duration(seconds: 8));
            if (infoResponse.statusCode == 200) {
              final data =
                  jsonDecode(infoResponse.body) as Map<String, dynamic>;
              if (data['error'] != null) {
                sessionRejected = true;
              } else {
                final result = data['result'] as Map<String, dynamic>?;
                if (result != null &&
                    result['uid'] != false &&
                    result['uid'] != null) {
                  sessionResult = result;
                  sessionRejected = false;
                  break;
                }
                sessionRejected = true;
              }
            }
          } catch (_) {}
          if (attempt < 1) {
            await Future.delayed(const Duration(milliseconds: 600));
          }
        }
      }

      if (sessionResult == null && sessionRejected) {
        throw Exception('Session is not authenticated');
      }

      String? userLogin;
      String? userName;
      String? userLang;
      String? userTz;
      bool isSystem = false;
      String? serverVersion;
      int? partnerId;
      int? companyId;
      int? userId;

      if (sessionResult != null) {
        final userContext =
            sessionResult['user_context'] as Map<String, dynamic>?;
        userId =
            sessionResult['uid'] is int ? sessionResult['uid'] as int : null;
        userLogin =
            (sessionResult['username'] as String?) ??
            (sessionResult['login'] as String?) ??
            widget.username;
        userName = (sessionResult['name'] as String?) ?? widget.username;
        userLang =
            (sessionResult['lang'] as String?) ??
            (userContext?['lang'] as String?) ??
            'en_US';
        userTz =
            (sessionResult['tz'] as String?) ??
            (userContext?['tz'] as String?) ??
            '';
        isSystem = (sessionResult['is_system'] as bool?) ?? false;
        serverVersion = (sessionResult['server_version'] as String?) ?? '';

        final rawPartnerId = sessionResult['partner_id'];
        partnerId =
            rawPartnerId is int
                ? rawPartnerId
                : (rawPartnerId is List && rawPartnerId.isNotEmpty
                    ? rawPartnerId[0] as int
                    : null);

        final rawCompanyId = sessionResult['company_id'];
        companyId =
            rawCompanyId is int
                ? rawCompanyId
                : (rawCompanyId is List && rawCompanyId.isNotEmpty
                    ? rawCompanyId[0] as int
                    : null);
      }

      // Fetch the profile photo so it's available for this account's entry
      // in the switch-accounts list, which reads it from storage rather
      // than the live server (unlike the top profile card, which always
      // fetches fresh) — without this, an account added via 2FA would show
      // a blank/generic avatar there.
      String imageBase64 = '';
      if (userId != null) {
        try {
          final imageResponse = await http
              .post(
                Uri.parse('$_serverUrl/web/dataset/call_kw'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'X-Requested-With': 'XMLHttpRequest',
                  'User-Agent': _desktopUserAgent,
                  'Origin': _serverUrl,
                  'Referer': '$_serverUrl/web',
                  'Cookie': 'session_id=${_sessionId!}',
                },
                body: jsonEncode({
                  'jsonrpc': '2.0',
                  'method': 'call',
                  'params': {
                    'model': 'res.users',
                    'method': 'read',
                    'args': [
                      [userId],
                      ['image_1920'],
                    ],
                    'kwargs': {},
                  },
                }),
              )
              .timeout(const Duration(seconds: 8));
          if (imageResponse.statusCode == 200) {
            final data = jsonDecode(imageResponse.body) as Map<String, dynamic>;
            final result = data['result'];
            if (result is List &&
                result.isNotEmpty &&
                ImageUtils.base64Of(result[0]['image_1920']).isNotEmpty) {
              imageBase64 = ImageUtils.base64Of(result[0]['image_1920']);
            }
          }
        } catch (e) {}
      }

      await AuthService().saveAuthenticatedSession(
        url: _serverUrl,
        database: widget.database,
        username: widget.username,
        password: widget.password,
        sessionId: _sessionId!,
        userId: userId,
        userLogin: userLogin,
        userName: userName,
        partnerId: partnerId,
        userLang: userLang,
        userTz: userTz,
        isSystem: isSystem,
        serverVersion: serverVersion,
        companyId: companyId,
        imageBase64: imageBase64,
        // Lets any future silent session-expiry relogin logic know a
        // password-only `client.authenticate()` retry can never succeed for
        // this account and should hand off back through this 2FA flow.
        twoFactorRequired: true,
      );
      TwoFactorAuth.resetReloginHandoffs();

      // Purge the outgoing WebView state before the app's own webview
      // re-establishes the session from prefs — otherwise a stale cached
      // session for a different account can surface.
      try {
        await CookieManager.instance().deleteAllCookies();
        await InAppWebViewController.clearAllCache();
        await WebStorageManager.instance().deleteAllData();
      } catch (_) {}

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(widget.onSuccessRouteName, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _verifying = false;
          _loading = false;
          _error = e is DatabaseExpiredException
              ? DatabaseExpiredException.message
              : 'Invalid code or login failed. Please try again.';
        });
      }
    }
  }
}
