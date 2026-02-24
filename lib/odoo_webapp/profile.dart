import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../core/motion_provider.dart';
import '../core/style.dart';
import '../services/storage_service.dart';
import '../settings/settings_screen.dart';
import '../Loginpage/switch_account_screen.dart';
import '../widgets/logout_dialog.dart';
import 'profile_edit.dart';
import '../core/image_utils.dart';

class ProfilePage extends StatefulWidget {
  final Uint8List? profileImageBytes;
  final String? userName;
  final String? mail;
  final Future<void> Function()? refreshProfile;
  final Function(Uint8List)? onProfilePictureUpdated;

  const ProfilePage({
    super.key,
    this.profileImageBytes,
    this.userName,
    this.mail,
    this.refreshProfile,
    this.onProfilePictureUpdated,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late StorageService storageService;
  List<dynamic> profiles = [];
  int? userId;
  int? companyId;
  bool? isSystem;
  late SharedPreferences prefs;
  bool isLoading = false;
  bool isProfileLoading = false;

  @override
  void initState() {
    super.initState();
    storageService = StorageService();
    _initializeOdooClient();
  }

  Future<void> _initializeOdooClient() async {
    prefs = await SharedPreferences.getInstance();
    if (widget.profileImageBytes == null &&
        widget.userName == null &&
        widget.mail == null) {
      setState(() {
        isProfileLoading = true;
      });
    }

    await loadProfile();
    setState(() {
      isProfileLoading = false;
    });
  }

  Future<void> loadProfile() async {
    final serverUrl = prefs.getString('uri');
    if (serverUrl == null) return;
    
    final client = OdooClient(serverUrl);
    try {
      final userIdStr = prefs.getString('userId') ?? '';
      final dbName = prefs.getString('dbName');
      final username = prefs.getString('username');
      final userLogin = prefs.getString('userLogin');
      final password = prefs.getString('password');
      
      final authLogin = userLogin ?? username;

      if (dbName == null || authLogin == null || password == null || userIdStr.isEmpty) return;

      await client.authenticate(dbName, authLogin, password);

      final fieldsResponse = await client.callKw({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [],
        'kwargs': {'attributes': ['type']}
      });
      final availableFields = fieldsResponse as Map<String, dynamic>;
      final mobileField = availableFields.containsKey('mobile')
          ? 'mobile'
          : (availableFields.containsKey('mobile_phone') ? 'mobile_phone' : null);

      final fields = [
        'id',
        'name',
        'phone',
        'email',
        'contact_address',
        'company_id',
        'street',
        'street2',
        'state_id',
        'country_id',
        'image_1920',
        'website',
        'function',
        if (mobileField != null) mobileField,
      ];

      final response = await client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', int.parse(userIdStr)],
          ],
        ],
        'kwargs': {'fields': fields},
      });

      if (response is List && response.isNotEmpty) {
        profiles = List<Map<String, dynamic>>.from(response);
        
        // If profile picture updated, notify parent
        if (widget.onProfilePictureUpdated != null && profiles.first['image_1920'] is String) {
          try {
            final imageData = profiles.first['image_1920'] as String;
            if (imageData.isNotEmpty) {
              final bytes = base64Decode(imageData);
              if (ImageUtils.isValidImage(bytes)) {
                widget.onProfilePictureUpdated!(bytes);
              } else {
              }
            }
          } catch (e) {
          }
        }
      }
      
      if (mounted) setState(() {});
    } catch (e) {
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await widget.refreshProfile?.call();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.grey[50],
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.refreshProfile != null) widget.refreshProfile!();
            },
          ),
          title: Text(
            'Configuration',
            style: AppStyle.font(
              color: isDark ? Colors.white : Colors.black,
              weight: FontWeight.w600,
              size: 22,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ProfileFormPage(refreshProfile: loadProfile),
                          transitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          reverseTransitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            if (motionProvider.reduceMotion) return child;
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppStyle.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          isProfileLoading
                              ? const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 30,
                                        color: AppStyle.primaryColor,
                                      ),
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppStyle.primaryColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                               :ClipOval(
                                  child: (profiles.isNotEmpty &&
                                          profiles.first['image_1920'] is String &&
                                          (profiles.first['image_1920'] as String)
                                              .isNotEmpty)
                                      ? Builder(
                                          builder: (context) {
                                            try {
                                              final bytes = base64Decode(profiles.first['image_1920'] as String);
                                              if (ImageUtils.isValidImage(bytes)) {
                                                return Image.memory(
                                                  bytes,
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
                                                );
                                              }
                                            } catch (e) {
                                            }
                                            return _buildFallbackAvatar();
                                          },
                                        )
                                      : (widget.profileImageBytes != null && ImageUtils.isValidImage(widget.profileImageBytes)
                                          ? Image.memory(
                                              widget.profileImageBytes!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) => _buildFallbackAvatar(),
                                            )
                                          : Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.person,
                                                size: 30,
                                                color: AppStyle.primaryColor,
                                              ),
                                            )),
                                ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                isProfileLoading
                                    ? Shimmer.fromColors(
                                        baseColor: AppStyle.primaryColor,
                                        highlightColor: Colors.grey.shade300,
                                        child: Container(
                                          width: 120,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        profiles.isNotEmpty
                                            ? (profiles.first['name'] ??
                                                "Unknown")
                                            : (widget.userName ?? "Unknown"),
                                        style: AppStyle.font(
                                          color: Colors.white,
                                          size: 17,
                                          weight: FontWeight.w700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                const SizedBox(height: 4),
                                isProfileLoading
                                    ? Shimmer.fromColors(
                                        baseColor: AppStyle.primaryColor,
                                        highlightColor: Colors.grey.shade300,
                                        child: Container(
                                          width: 140,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        profiles.isNotEmpty
                                            ? (profiles.first['email'] is String ? profiles.first['email'] : "")
                                            : (widget.mail ?? "Unknown"),
                                        style: AppStyle.font(
                                          color: Colors.white,
                                          size: 13,
                                          weight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.settings_outlined,
                            color:
                                isDark ? Colors.grey[400]! : Colors.grey[600]!,
                          ),
                          title: Text(
                            "Settings",
                            style: AppStyle.font(
                              color: isDark ? Colors.white : Colors.black87,
                              weight: FontWeight.normal,
                              size: 16,
                            ),
                          ),
                          subtitle: Text(
                            "App preferences and sync options",
                            style: AppStyle.font(
                              color: isDark
                                  ? Colors.grey[400]!
                                  : Colors.grey[600]!,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const SettingsScreen(),
                                transitionDuration: motionProvider.reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                reverseTransitionDuration:
                                    motionProvider.reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 300),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  if (motionProvider.reduceMotion) return child;
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          indent: 20,
                          endIndent: 20,
                        ),
                        Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            leading: HugeIcon(
                              icon: HugeIcons.strokeRoundedUserSwitch,
                              color: isDark
                                  ? Colors.grey[400]!
                                  : Colors.grey[600]!,
                            ),
                            title: Text(
                              'Switch Accounts',
                              style: AppStyle.font(
                                color: isDark ? Colors.white : Colors.black87,
                                weight: FontWeight.normal,
                                size: 16,
                              ),
                            ),
                            subtitle: Text(
                              "Manage and switch between accounts",
                              style: AppStyle.font(
                                color: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            ),
                            children: [
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: storageService.getAccounts(),
                                builder: (context, snapshot) {
                                  final accounts = snapshot.data ?? [];
                                  final currentUserId =
                                      prefs.getString('userId');
                                  final currentServer = prefs.getString('uri');
                                  final currentDb = prefs.getString('dbName');

                                  final otherAccounts = accounts.where((user) {
                                    return !(user['userId'].toString() ==
                                            currentUserId &&
                                        user['uri'] == currentServer &&
                                        user['dbName'] == currentDb);
                                  }).toList();

                                  return Column(
                                    children: [
                                      if (otherAccounts.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            "No accounts found",
                                            style: AppStyle.font(
                                              weight: FontWeight.w500,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ...otherAccounts.map((user) {
                                        Uint8List? avatar;
                                        if (user['image'] != null &&
                                            user['image'] is String &&
                                            (user['image'] as String)
                                                .isNotEmpty) {
                                          try {
                                            avatar =
                                                base64Decode(user['image']);
                                          } catch (_) {}
                                        }

                                        return ListTile(
                                          leading: avatar != null
                                              ? Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: ClipOval(
                                                    child: (avatar != null && ImageUtils.isValidImage(avatar))
                                                      ? Image.memory(
                                                        avatar,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return const Icon(Icons.person);
                                                        },
                                                      )
                                                      : const Icon(Icons.person),
                                                  ),
                                                )
                                              : const CircleAvatar(
                                                  child: Icon(Icons.person),
                                                ),
                                          title: Text(
                                            user['userName'] ??
                                                user['username'],
                                            style: AppStyle.font(
                                              weight: FontWeight.w500,
                                              size: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          subtitle: Text(
                                            user['userLogin'] ?? "",
                                            style: AppStyle.font(
                                              weight: FontWeight.w400,
                                              size: 13,
                                              color: isDark
                                                  ? Colors.grey[400]!
                                                  : Colors.grey[600]!,
                                            ),
                                          ),
                                          trailing: TextButton(
                                            onPressed: () async {
                                              setState(() {
                                                isLoading = true;
                                              });
                                              await switchAccount(user);
                                              setState(() {
                                                isLoading = false;
                                              });
                                            },
                                            child: Text(
                                              "Switch",
                                              style: AppStyle.font(
                                                color: isDark
                                                    ? Colors.white
                                                    : AppStyle.primaryColor,
                                                weight: FontWeight.w500,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                  ) =>
                                                      const SwitchAccountScreen(),
                                                  transitionDuration:
                                                      motionProvider
                                                              .reduceMotion
                                                          ? Duration.zero
                                                          : const Duration(
                                                              milliseconds: 300,
                                                            ),
                                                  reverseTransitionDuration:
                                                      motionProvider
                                                              .reduceMotion
                                                          ? Duration.zero
                                                          : const Duration(
                                                              milliseconds: 300,
                                                            ),
                                                  transitionsBuilder: (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child,
                                                  ) {
                                                    if (motionProvider
                                                        .reduceMotion)
                                                      return child;
                                                    return FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    );
                                                  },
                                                ),
                                              ).then((_) => loadProfile());
                                            },
                                            icon: const HugeIcon(
                                              icon: HugeIcons.strokeRoundedUserAdd01,
                                            ),
                                            label: Text(
                                              "Add Account",
                                              style: AppStyle.font(
                                                weight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark
                                                  ? Colors.white
                                                  : AppStyle.primaryColor,
                                              foregroundColor: isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  12,
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
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color:
                              isDark ? Colors.grey[800] : Colors.grey.shade200,
                          indent: 20,
                          endIndent: 20,
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout,
                              color: Color(0xFFD32F2F)),
                          title: Text(
                            "Logout",
                            style: AppStyle.font(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFFD32F2F),
                              weight: FontWeight.normal,
                              size: 16,
                            ),
                          ),
                          subtitle: Text(
                            "Sign out from this device",
                            style: AppStyle.font(
                              color: isDark
                                  ? Colors.grey[400]!
                                  : Colors.grey[600]!,
                            ),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  LogoutDialog(storageService: storageService),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: LoadingAnimationWidget.fourRotatingDots(
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                      size: 50,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> switchAccount(Map<String, dynamic> user) async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageService = StorageService();
      
      await prefs.setString('uri', user['uri']);
      await prefs.setString('dbName', user['dbName']);
      await prefs.setString('password', user['password']);
      await prefs.setString('session_id', user['sessionId']);
      await prefs.setString('userId', user['userId'].toString());
      await prefs.setString('username', user['username']);
      await prefs.setString('userLogin', user['userLogin'] ?? user['username']);
      await prefs.setString('userName', user['username']);
      await prefs.setString('companyId', user['companyId'].toString());
      
      final client = OdooClient(user['uri']);
      final session = await client.authenticate(
        user['dbName'],
        user['userLogin'] ?? user['username'],
        user['password'],
      );

      await storageService.saveSession(session);
      await storageService.saveLoginState(
        isLoggedIn: true,
        database: user['dbName'],
        url: user['uri'],
        password: user['password'],
      );

      final accounts = await storageService.getAccounts();
      final updatedAccounts = accounts.map((a) {
        if (a['userId'] == user['userId'] &&
            a['uri'] == user['uri'] &&
            a['dbName'] == user['dbName']) {
          a['lastLogin'] = DateTime.now().toIso8601String();
        }
        return a;
      }).toList();
      await prefs.setString('loggedInAccounts', jsonEncode(updatedAccounts));

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/webapp',
          (route) => false,
          arguments: {
            'serverUrl': user['uri'],
            'dbName': user['dbName'],
            'sessionId': session.id,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to switch account: $e")),
        );
      }
    }
  }
  Widget _buildFallbackAvatar() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      child: const Icon(
        Icons.person,
        size: 30,
        color: AppStyle.primaryColor,
      ),
    );
  }
}
