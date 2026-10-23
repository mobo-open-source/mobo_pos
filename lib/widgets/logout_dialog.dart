import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Loginpage/server_setup_screen.dart';
import '../core/style.dart';
import '../providers/theme_provider.dart';
import '../shared/widgets/snackbar.dart';
import '../services/storage_service.dart';

class LogoutDialog extends StatefulWidget {
  final StorageService storageService;

  const LogoutDialog({required this.storageService});

  @override
  _LogoutDialogState createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<LogoutDialog> {
  bool isLogoutLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      title: Text(
        "Confirm Logout",
        style: AppStyle.font(
          weight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
          size: 18,
        ),
      ),
      content: Text(
        'Are you sure you want to log out? Your session will be ended.',
        style: AppStyle.font(
          weight: FontWeight.normal,
          color: isDark ? Colors.white : Colors.black,
          size: 15,
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  "CANCEL",
                  style: AppStyle.font(
                    weight: FontWeight.bold,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    size: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _performLogout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child:
                    isLogoutLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          "CONTINUE",
                          style: AppStyle.font(
                            color: Colors.white,
                            weight: FontWeight.bold,
                            size: 12,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    setState(() => isLogoutLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.fourRotatingDots(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  "Logging out...",
                  style: AppStyle.font(size: 18, weight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait while we process your request.",
                  textAlign: TextAlign.center,
                  style: AppStyle.font(size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();

    final serverUrl = prefs.getString('uri');
    final sessionId = prefs.getString('session_id');
    final dbName = prefs.getString('dbName');

    // Best-effort: end the session server-side and clear the WebView's
    // cookies before wiping local state. Failures here shouldn't block
    // logging out locally.
    if (serverUrl != null &&
        serverUrl.isNotEmpty &&
        sessionId != null &&
        sessionId.isNotEmpty &&
        dbName != null) {
      OdooClient? client;
      try {
        client = OdooClient(
          serverUrl,
          sessionId: OdooSession(
            id: sessionId,
            userId: int.tryParse(prefs.getString('userId') ?? '0') ?? 0,
            partnerId: int.tryParse(prefs.getString('partnerId') ?? '0') ?? 0,
            userLogin: prefs.getString('userLogin') ?? '',
            userName: prefs.getString('userName') ?? '',
            userLang: prefs.getString('userLang') ?? 'en_US',
            userTz: prefs.getString('userTz') ?? 'UTC',
            isSystem: prefs.getBool('isSystem') ?? false,
            dbName: dbName,
            serverVersion: prefs.getString('serverVersion') ?? '',
            companyId: int.tryParse(prefs.getString('companyId') ?? '1') ?? 1,
            allowedCompanies: const [],
          ),
        );
        await client.callRPC('/web/session/logout', 'call', {});
      } catch (_) {
      } finally {
        client?.close();
      }

      try {
        await CookieManager.instance().deleteAllCookies();
      } catch (_) {}
    }

    // Preserve device-level preferences that shouldn't reset on logout —
    // the user's saved server suggestions, the one-time onboarding flag,
    // and their biometric preference — everything else (session, account
    // credentials) is cleared.
    final urlHistory = prefs.getStringList('urlHistory') ?? [];
    final isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    await prefs.clear();
    await prefs.setStringList('urlHistory', urlHistory);
    await prefs.setBool('hasSeenGetStarted', isGetStarted);
    await prefs.setBool('biometric_enabled', biometricEnabled);

    if (context.mounted) {
      // Dark mode is a per-login preference, not a device-level one - it
      // shouldn't carry over into the next login on any server, and
      // prefs.clear() above already dropped the persisted 'theme_mode', but
      // the in-memory ThemeProvider still needs resetting so the UI itself
      // switches back to light immediately instead of only on next app start.
      Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).setThemeMode(ThemeMode.light);
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close confirmation dialog
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ServerSetupScreen()),
        (route) => false,
      );
      CustomSnackbar.showSuccess(context, 'Logged out successfully');
    }

    setState(() => isLogoutLoading = false);
  }
}
