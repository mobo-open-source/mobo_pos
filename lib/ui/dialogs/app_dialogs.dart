import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDialogs {
  const AppDialogs._();

  static const Color _primaryColor = Color(0xFFC03355);
  static const Color _destructiveColor = Color(0xFFD32F2F);

  static TextStyle _font({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = _primaryColor,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color confirmBg = isDestructive ? _destructiveColor : _primaryColor;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: _font(
              weight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              size: 18,
            ),
          ),
          content: Text(
            message,
            style: _font(
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
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      side: BorderSide(
                        color: isDark ? Colors.white : _primaryColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      cancelText.toUpperCase(),
                      style: _font(
                        weight: FontWeight.bold,
                        color: isDark ? Colors.white : _primaryColor,
                        size: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      confirmText.toUpperCase(),
                      style: _font(
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
      },
    );
  }

  /// A non-dismissible "required module missing" dialog: a warning icon next
  /// to the title, a single full-width action button, and no way to
  /// dismiss it without tapping that button — the account genuinely can't be
  /// used until the caller acts on it (e.g. logging out), unlike
  /// [showConfirm]'s two-choice dialogs which leave a real option to cancel.
  static Future<void> showModuleMissing(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'Back to Login',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: _destructiveColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: _font(
                    weight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: _font(
              weight: FontWeight.normal,
              color: isDark ? Colors.white : Colors.black87,
              size: 15,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: _font(
                    color: Colors.white,
                    weight: FontWeight.w600,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A single-button informational dialog, for messages the user just needs
  /// to acknowledge (no confirm/cancel choice).
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: _font(
              weight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              size: 18,
            ),
          ),
          content: Text(
            message,
            style: _font(
              weight: FontWeight.normal,
              color: isDark ? Colors.white : Colors.black,
              size: 15,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white : _primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  buttonText.toUpperCase(),
                  style: _font(
                    weight: FontWeight.bold,
                    color: isDark ? Colors.white : _primaryColor,
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
