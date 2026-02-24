import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:mobo_pos/Loginpage/login.dart';
import '../services/biometric_service.dart';
import '../screens/company_profile_screen.dart';
import '../providers/theme_provider.dart';
import '../ui/dialogs/app_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  List<String> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricAvailability();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await BiometricService.isBiometricAvailable();
      final availableBiometrics = await BiometricService.getAvailableBiometricNames();
      
      if (mounted) {
        setState(() {
          _biometricAvailable = isAvailable;
          _availableBiometrics = availableBiometrics;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _biometricAvailable = false;
          _availableBiometrics = [];
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    await BiometricService.setBiometricEnabled(_biometricEnabled);
  }

  // Future<void> _launchUrl(String url) async {
  //   try {
  //     final Uri uri = Uri.parse(url);
  //     if (await canLaunchUrl(uri)) {
  //       await launchUrl(uri, mode: LaunchMode.externalApplication);
  //     } else {
  //       if (mounted) {
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('Could not launch $url'),
  //             backgroundColor: Colors.red,
  //           ),
  //         );
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Error launching URL: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }


  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);

      // Special handling for mailto URLs
      if (url.startsWith('mailto:')) {
        try {
          // Try to launch directly without canLaunchUrl check
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          // If launch fails, offer to copy the email address
          if (mounted) {
            final email = url.replaceFirst('mailto:', '');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open email app. Email: $email'),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Copy',
                  textColor: Colors.white,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      } else {
        // Handle other URLs normally
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not launch $url'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Check if biometric is available first
      if (!_biometricAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Biometric authentication is not available on this device. '
                'Please ensure you have set up fingerprint, face recognition, or PIN in your device settings.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Testing biometric authentication...'),
                ],
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Test biometric authentication before enabling
        final bool authenticated = await BiometricService.authenticateWithBiometrics(
          reason: 'Please authenticate to enable biometric login for Odoo POS',
        );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Biometric authentication failed. Please try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Authentication successful, enable biometric
        setState(() {
          _biometricEnabled = true;
        });
        
        await _saveSettings();

        if (mounted) {
          final biometricTypes = _availableBiometrics.isNotEmpty 
              ? _availableBiometrics.join(', ') 
              : 'Biometric';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$biometricTypes authentication enabled successfully!'),
              backgroundColor: const Color(0xFFC03355),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error setting up biometric authentication: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    } else {
      // Disable biometric
      setState(() {
        _biometricEnabled = false;
      });
      
      await _saveSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication disabled'),
            backgroundColor: const Color(0xFFC03355),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Settings',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: isDark ? Colors.white : Colors.black
            )),
        backgroundColor: backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(icon:
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white :Colors.black
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSectionCard(
            context,
            'Account',
            HugeIcons.strokeRoundedUser,
            [
              _buildActionTile(
                context,
                'My Odoo Account',
                'Access your odoo.com account',
                HugeIcons.strokeRoundedGlobe02,
                () => _launchUrl('https://www.odoo.com/'),
              ),
              _buildActionTile(
                context,
                'Company Profile',
                'View and edit company information',
                HugeIcons.strokeRoundedBuilding06,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CompanyProfileScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Appearance Section
          _buildSectionCard(
            context,
            'Appearance',
            HugeIcons.strokeRoundedPaintBoard,
            [
              _buildSwitchTile(
                context,
                'Dark Mode',
                'Switch between light and dark themes',
                HugeIcons.strokeRoundedMoon02,
                Theme.of(context).brightness == Brightness.dark,
                (value) {
                  final themeProvider = context.read<ThemeProvider>();
                  themeProvider.toggleTheme();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Theme changed to ${value ? 'dark' : 'light'} mode'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Security Section
          _buildSectionCard(
            context,
            'Security',
            HugeIcons.strokeRoundedLockPassword,
            [
              _buildSwitchTile(
                context,
                'Biometric Authentication',
                _biometricAvailable 
                    ? (_availableBiometrics.isNotEmpty 
                        ? 'Use ${_availableBiometrics.join(', ')} to unlock the app'
                        : 'Use biometric authentication to unlock the app')
                    : 'Biometric authentication not available on this device',
                _getBiometricIcon(),
                _biometricEnabled,
                _biometricAvailable ? _toggleBiometric : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Help & Support Section
          _buildSectionCard(
            context,
            'Help & Support',
            HugeIcons.strokeRoundedCustomerSupport,
            [
              _buildActionTile(
                context,
                'Documentation',
                'Guides and resources',
                HugeIcons.strokeRoundedHelpCircle,
                () => _launchUrl('https://www.odoo.com/documentation'),
              ),
              _buildActionTile(
                context,
                'Support',
                'Get help from our support team',
                HugeIcons.strokeRoundedCustomerSupport,
                () => _launchUrl('https://www.odoo.com/help'),
              ),
              _buildActionTile(
                context,
                'Help Center',
                'Find answers to common questions',
                HugeIcons.strokeRoundedQuestion,
                () => _launchUrl('https://www.odoo.com/forum/help-1'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // About Section
          _buildSectionCard(
            context,
            'About',
            HugeIcons.strokeRoundedBuilding06,
            [
              _buildAboutContent(context),
            ],
          ),
          
          const SizedBox(height: 16),

          // Account Actions Section
          // _buildSectionCard(
          //   context,
          //   'Account Actions',
          //   HugeIcons.strokeRoundedSettings02,
          //   [
          //     _buildActionTile(
          //       context,
          //       'Logout',
          //       'Sign out of your account',
          //       HugeIcons.strokeRoundedLogout01,
          //       () => _showLogoutDialog(context),
          //       isDestructive: true,
          //     ),
          //   ],
          // ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
      List<List<dynamic>> icon,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[850]! : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    String title,
    String subtitle,
      List<List<dynamic>> icon,
    VoidCallback? onTap, {
    bool isDestructive = false,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87);

    return ListTile(
      leading: HugeIcon(icon:
        icon,
        color:isDark?Colors.grey[300]: Colors.black,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          : null,
      trailing: trailing ??
          HugeIcon(icon:
            HugeIcons.strokeRoundedArrowRight01,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            size: 18,
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  List<List<dynamic>> _getBiometricIcon() {
    if (_availableBiometrics.contains('Face ID')) {
      return HugeIcons.strokeRoundedFaceId;
    } else if (_availableBiometrics.contains('Fingerprint')) {
      return HugeIcons.strokeRoundedFingerPrint;
    } else {
      return HugeIcons.strokeRoundedLockPassword;
    }
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
      List<List<dynamic>> icon,
    bool value,
    Function(bool)? onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: HugeIcon(icon:
        icon,
        color:isDark?Colors.grey[300]: Colors.black,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFC03355),
        activeTrackColor: const Color(0xFFC03355).withOpacity(0.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildAboutContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          _buildActionTile(
            context,
            'Visit Website',
            'www.cybrosys.com',
            HugeIcons.strokeRoundedGlobe02,
            () => _launchUrl('https://www.cybrosys.com/'),
          ),
          _buildActionTile(
            context,
            'Contact Us',
            'info@cybrosys.com',
            HugeIcons.strokeRoundedMail01,
            () => _launchUrl('mailto:info@cybrosys.com'),
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'Follow Us',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSocialButton(
                context,
                'assets/linkedin.png',
                const Color(0xFF0077B5),
                'LinkedIn',
                () => _launchUrl('https://www.linkedin.com/company/cybrosys/'),
              ),
              _buildSocialButton(
                context,
                'assets/youtube.png',
                const Color(0xFFFF0000),
                'YouTube',
                () => _launchUrl('https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg'),
              ),
              _buildSocialButton(
                context,
                'assets/instagram.png',
                const Color(0xFFE4405F),
                'Instagram',
                () => _launchUrl('https://www.instagram.com/cybrosystech/'),
              ),
              _buildSocialButton(
                context,
                'assets/facebook.png',
                const Color(0xFF1877F2),
                'Facebook',
                () => _launchUrl('https://www.facebook.com/cybrosystechnologies'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} Cybrosys Technologies',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Odoo Community POS',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context, String imagePath,
      Color underlineColor, String label, VoidCallback onPressed) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              imagePath,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icons if images are not available
                List<List<dynamic>> fallbackIcon;
                switch (label) {
                  case 'LinkedIn':
                    fallbackIcon = HugeIcons.strokeRoundedLinkedin01;
                    break;
                  case 'YouTube':
                    fallbackIcon = HugeIcons.strokeRoundedYoutube;
                    break;
                  case 'Instagram':
                    fallbackIcon = HugeIcons.strokeRoundedInstagram;
                    break;
                  case 'Facebook':
                    fallbackIcon = HugeIcons.strokeRoundedFacebook01;
                    break;
                  default:
                    fallbackIcon = HugeIcons.strokeRoundedGlobe02;
                }
                return HugeIcon(icon:
                  fallbackIcon,
                  size: 24,
                  color: underlineColor,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: underlineColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to log out? Your session will be ended.',
      confirmText: 'Log Out',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    
    if (confirmed == true && context.mounted) {
      // Here you would implement the actual logout functionality
      // For now, just show a message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout functionality would be implemented here'),
          backgroundColor: const Color(0xFFC03355),
        ),
      );
      Navigator.of(context).pop(); // Go back to previous screen
    }
  }
}
