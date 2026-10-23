import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/widgets/snackbar.dart';
import 'package:provider/provider.dart';
import '../services/biometric_service.dart';
import '../services/setting_service.dart';
import '../core/motion_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/company_profile_screen.dart';
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

  String? _userId;
  String _language = 'English (US)';
  String _languageCode = 'en_US';
  String _currency = 'United States dollar';
  String _timezone = 'UTC';
  List<Map<String, dynamic>> _languages = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _timezones = [];
  bool _isLanguageLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometricAvailability();
    _loadLanguageAndRegion();
  }

  Future<void> _loadLanguageAndRegion() async {
    setState(() => _isLanguageLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getString('userId');

      final settingService = SettingService();
      await settingService.initializeClient();

      final languages = await settingService.fetchLanguage();
      final currencies = await settingService.fetchCurrency();
      final timezones = await settingService.fetchTimezones();

      if (mounted) {
        setState(() {
          if (languages != null) {
            _languages = List<Map<String, dynamic>>.from(languages);
          }
          if (currencies != null) {
            _currencies = List<Map<String, dynamic>>.from(currencies);
          }
          _timezones = timezones;
        });
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLanguageLoading = false);
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      // Restore the last locally-chosen Language & Region selections, so
      // they survive navigating away/restarting the app rather than
      // resetting to the hardcoded defaults every time this screen opens.
      _language = prefs.getString('settings_language') ?? _language;
      _currency = prefs.getString('settings_currency') ?? _currency;
      _timezone = prefs.getString('settings_timezone') ?? _timezone;
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await BiometricService.isBiometricAvailable();
      final availableBiometrics =
          await BiometricService.getAvailableBiometricNames();

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
        final bool authenticated =
            await BiometricService.authenticateWithBiometrics(
              reason:
                  'Please authenticate to enable biometric login for Odoo POS',
            );

        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Biometric authentication failed. Please try again.',
                ),
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
          final biometricTypes =
              _availableBiometrics.isNotEmpty
                  ? _availableBiometrics.join(', ')
                  : 'Biometric';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$biometricTypes authentication enabled successfully!',
              ),
              backgroundColor: const Color(0xFFC03355),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error setting up biometric authentication: ${e.toString()}',
              ),
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Appearance Section
            _buildSectionCard(context, 'Appearance', [
              const SizedBox(height: 8),
              _buildSwitchTile(
                context,
                'Dark Mode',
                isDark ? 'Dark theme is active' : 'Light theme is active',
                HugeIcons.strokeRoundedSun02,
                context.watch<ThemeProvider>().isDarkMode,
                (value) {
                  context.read<ThemeProvider>().toggleTheme();
                  CustomSnackbar.showSuccess(
                    context,
                    'Theme changed to ${value ? 'dark' : 'light'} mode',
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildSwitchTile(
                context,
                'Reduce Motion',
                'Minimize animations and motion effect',
                Icons.visibility_off,
                context.watch<MotionProvider>().reduceMotion,
                (value) {
                  context.read<MotionProvider>().setReduceMotion(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value
                            ? 'Motion effects reduced'
                            : 'Motion effects restored',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  );
                },
              ),
            ]),

            // Security Section
            _buildSectionCard(context, 'Security', [
              _buildSwitchTile(
                context,
                'App Lock',
                _biometricAvailable
                    ? (_biometricEnabled
                        ? 'Biometric lock is enabled'
                        : 'Enable biometric lock to keep your app secure')
                    : 'Biometric authentication is not available on this device',
                _biometricAvailable
                    ? HugeIcons.strokeRoundedFingerPrint
                    : HugeIcons.strokeRoundedLockPassword,
                _biometricEnabled,
                (value) {
                  if (_biometricAvailable) {
                    _toggleBiometric(value);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Biometric authentication not available on this device'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ]),

            // Language & Region Section
            _buildLanguageRegionCard(context),

            // Account Section
            _buildSectionCard(context, 'Account', [
              _buildActionTile(
                context,
                'Company Profile',
                'View and edit company information',
                HugeIcons.strokeRoundedBuilding06,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CompanyProfileScreen()),
                ),
              ),
            ]),

            // Help & Support Section
            _buildSectionCard(context, 'Help & Support', [
              _buildActionTile(
                context,
                'Odoo Help Center',
                'Documentation, guides and resources',
                HugeIcons.strokeRoundedHelpCircle,
                () => _launchUrl('https://www.odoo.com/documentation'),
              ),
              _buildActionTile(
                context,
                'Odoo Support',
                'Create a ticket with Odoo Support',
                HugeIcons.strokeRoundedCustomerSupport,
                () => _launchUrl('https://www.odoo.com/help'),
              ),
              _buildActionTile(
                context,
                'Odoo Community Forum',
                'Ask the community for help',
                HugeIcons.strokeRoundedQuestion,
                () => _launchUrl('https://www.odoo.com/forum/help-1'),
              ),
            ]),

            // About Section
            _buildSectionCard(context, 'About', [_buildAboutContent(context)]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRegionCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F1F1F) : Colors.white;

    final currencyItems =
        _currencies
            .map((e) => e['full_name'].toString())
            .toSet()
            .map((e) => {'full_name': e})
            .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Language & Region',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: isDark ? Colors.grey[300] : Colors.grey[600],
                    size: 20,
                  ),
                  onPressed: _isLanguageLoading ? null : _loadLanguageAndRegion,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDropdownTile(
              context,
              'Language',
              'Select your preferred language',
              HugeIcons.strokeRoundedTranslate,
              _language,
              _languages,
              'name',
              (selectedName) async {
                if (selectedName == null) return;
                final selectedLang = _languages.firstWhere(
                  (lang) => lang['name'] == selectedName,
                  orElse: () => {},
                );
                if (selectedLang.isEmpty) return;

                setState(() => _language = selectedName);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('settings_language', selectedName);
                final settingService = SettingService();
                await settingService.initializeClient();
                final success = await settingService.updateLanguage(
                  int.tryParse(_userId ?? '') ?? 0,
                  {'lang': selectedLang['code']},
                );
                if (!mounted) return;
                _languageCode =
                    (selectedLang['code'] ?? _languageCode).toString();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Language updated successfully'
                          : 'Failed to update language. Please try again later.',
                    ),
                    backgroundColor:
                        success ? Theme.of(context).primaryColor : Colors.red,
                  ),
                );
              },
            ),
            _buildDropdownTile(
              context,
              'Currency',
              'Default currency for transactions',
              HugeIcons.strokeRoundedDollar01,
              _currency,
              currencyItems,
              'full_name',
              (selected) async {
                if (selected == null) return;
                setState(() => _currency = selected);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('settings_currency', selected);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Currency updated successfully'),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                );
              },
            ),
            _buildDropdownTile(
              context,
              'Timezone',
              'Your local timezone',
              HugeIcons.strokeRoundedClock01,
              _timezone,
              _timezones,
              'name',
              (selectedName) async {
                if (selectedName == null) return;
                final selectedTz = _timezones.firstWhere(
                  (tz) => tz['name'] == selectedName,
                  orElse: () => {},
                );
                if (selectedTz.isEmpty) return;

                setState(() => _timezone = selectedName);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('settings_timezone', selectedName);
                final settingService = SettingService();
                await settingService.initializeClient();
                final success = await settingService.updateLanguage(
                  int.tryParse(_userId ?? '') ?? 0,
                  {'tz': selectedTz['code']},
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Timezone updated successfully'
                          : 'Failed to update timezone. Please try again later.',
                    ),
                    backgroundColor:
                        success ? Theme.of(context).primaryColor : Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile(
    BuildContext context,
    String title,
    String subtitle,
    List<List<dynamic>> icon,
    String value,
    List<Map<String, dynamic>> items,
    String displayKey,
    ValueChanged<String?> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: HugeIcon(
        icon: icon,
        color: isDark ? Colors.grey[300] : Colors.black,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child:
              _isLanguageLoading
                  ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : DropdownButton<String>(
                    value:
                        items.any((e) => e[displayKey].toString() == value)
                            ? value
                            : null,
                    hint: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                    items:
                        items.map((item) {
                          final itemValue = item[displayKey].toString();
                          return DropdownMenuItem<String>(
                            value: itemValue,
                            child: Text(
                              itemValue,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: onChanged,
                    underline: const SizedBox(),
                    dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                    isDense: true,
                    isExpanded: true,
                  ),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
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
        isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black);

    return ListTile(
      leading: HugeIcon(
        icon: icon,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 15,
          color: textColor,
        ),
      ),
      subtitle:
          subtitle.isNotEmpty
              ? Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              )
              : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    // Either a HugeIcons `List<List<dynamic>>` or a plain Material
    // `IconData` (fullsuite's own Reduce Motion tile uses Icons.visibility_off,
    // not a HugeIcon).
    dynamic icon,
    bool value,
    Function(bool)? onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon is IconData
              ? Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600])
              : HugeIcon(
                icon: icon as List<List<dynamic>>,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FlutterSwitch(
            width: 60,
            activeColor: const Color(0xFFC03355),
            inactiveColor: isDark ? Colors.black : Colors.white,
            value: value,
            onToggle: onChanged ?? (_) {},
            activeToggleColor: isDark ? Colors.black : Colors.white,
            inactiveToggleColor: const Color(0xFFC03355),
            showOnOff: false,
            switchBorder: Border.all(
              color: const Color(0xFFC03355).withOpacity(0.7),
              width: 1.5,
            ),
            borderRadius: 30.0,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? Colors.grey[400] : Colors.grey[600];

    return Column(
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
        _buildActionTile(
          context,
          'More Apps',
          'View our other apps',
          HugeIcons.strokeRoundedGridView,
          () {
            if (Platform.isIOS) {
              _launchUrl(
                'https://apps.apple.com/us/developer/cybrosys-technologies/id1805306445',
              );
            } else if (Platform.isAndroid) {
              _launchUrl(
                'https://play.google.com/store/apps/developer?id=Cybrosys',
              );
            }
          },
        ),
        const SizedBox(height: 12),
        Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
        const SizedBox(height: 8),
        Text(
          'Follow Us',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              context,
              'assets/facebook.png',
              const Color(0xFF1877F2),
              'Facebook',
              () => _launchUrl('https://www.facebook.com/cybrosystechnologies'),
            ),
            _buildSocialButton(
              context,
              'assets/linkedin.png',
              const Color(0xFF0077B5),
              'LinkedIn',
              () => _launchUrl('https://www.linkedin.com/company/cybrosys/'),
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
              'assets/youtube.png',
              const Color(0xFFFF0000),
              'YouTube',
              () => _launchUrl(
                'https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '© ${DateTime.now().year} Cybrosys Technologies',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: isDark ? Colors.white : Theme.of(context).primaryColor,
            ),
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
    );
  }

  Widget _buildSocialButton(
    BuildContext context,
    String imagePath,
    Color underlineColor,
    String label,
    VoidCallback onPressed,
  ) {
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
                return HugeIcon(
                  icon: fallbackIcon,
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
