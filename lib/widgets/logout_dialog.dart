import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/style.dart';
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
                    size: 12
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
                child: isLogoutLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        "CONTINUE",
                        style: AppStyle.font(
                          color: Colors.white,
                          weight: FontWeight.bold,
                          size: 12
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
                  style: AppStyle.font(
                    size: 18,
                    weight: FontWeight.w600,
                  ),
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
    bool isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    await prefs.clear();
    await prefs.setBool('hasSeenGetStarted', isGetStarted);

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.pop(context); // Close confirmation dialog
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      CustomSnackbar.showSuccess(context, 'Logged out successfully');
    }

    setState(() => isLogoutLoading = false);
  }
}
