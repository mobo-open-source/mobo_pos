import '../services/database_expiry.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:isar_community/isar.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../Isarmodel/Isar.dart';
import '../Isarmodel/user_profile.dart';
import '../core/motion_provider.dart';
import '../core/style.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import '../settings/settings_screen.dart';
import '../Loginpage/switch_account_screen.dart';
import '../Loginpage/two_factor_authentication.dart';
import '../ui/dialogs/app_dialogs.dart';
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
  List<Map<String, dynamic>> _otherAccounts = [];
  bool _accountsLoaded = false;

  @override
  void initState() {
    super.initState();
    storageService = StorageService();
    _initializeOdooClient();
    _loadOtherAccounts();
  }

  Future<void> _loadOtherAccounts() async {
    final accounts = await storageService.getAccounts();
    final p = await SharedPreferences.getInstance();
    final currentUserId = p.getString('userId');
    final currentServer = p.getString('uri');
    final currentDb = p.getString('dbName');

    final markedExpired = <String>{
      for (final k in p.getStringList('expired_databases') ?? <String>[]) k,
    };
    final others =
        accounts.where((user) {
          final key =
              '${(user['uri'] ?? '').toString().trim().replaceAll(RegExp(r'/+$'), '')}|${user['dbName'] ?? ''}';
          if (markedExpired.contains(key)) return false;
          return !(user['userId'].toString() == currentUserId &&
              user['uri'] == currentServer &&
              user['dbName'] == currentDb);
        }).toList();

    if (mounted) {
      setState(() {
        _otherAccounts = others;
        _accountsLoaded = true;
      });
    }

    // Drop saved accounts whose database has expired, so they can't be
    // switched to. Checked in parallel after the list is first shown.
    final expiredFlags = await Future.wait(
      others.map(
        (u) => DatabaseExpiry.isAccountExpired(
          url: (u['uri'] ?? '').toString(),
          database: (u['dbName'] ?? '').toString(),
          username: (u['userLogin'] ?? u['username'] ?? '').toString(),
          password: (u['password'] ?? '').toString(),
          sessionId: (u['sessionId'] ?? '').toString(),
        ),
      ),
    );
    final expired = <Map<String, dynamic>>[
      for (var i = 0; i < others.length; i++)
        if (expiredFlags[i]) others[i],
    ];
    if (expired.isEmpty) return;
    for (final user in expired) {
      await _purgeAccount(user);
    }
    if (mounted) {
      setState(() {
        _otherAccounts =
            others.where((u) => !expired.contains(u)).toList();
      });
    }
  }

  Future<void> _confirmAndRemoveAccount(Map<String, dynamic> user) async {
    final displayName =
        (user['userName'] ?? user['username'] ?? 'this account').toString();
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: 'Remove Account',
      message:
          'Are you sure you want to remove $displayName from your saved accounts?',
      confirmText: 'Remove',
      cancelText: 'Cancel',
      isDestructive: true,
    );
    if (confirmed != true) return;

    await _purgeAccount(user);
    await _loadOtherAccounts();
  }

  /// Removes a saved account from every store it lives in.
  Future<void> _purgeAccount(Map<String, dynamic> user) async {
    await storageService.removeAccount(user);

    final accountUsername =
        (user['username'] ?? user['userLogin'] ?? '').toString();
    final accountDb = (user['dbName'] ?? '').toString();
    final accountKey = '$accountUsername@$accountDb';
    try {
      final isar = await IsarService.instance;
      await isar.writeTxn(() async {
        await isar.userProfiles
            .filter()
            .accountKeyEqualTo(accountKey)
            .deleteAll();
        await isar.signedAccounts
            .where()
            .accountIdentifierEqualTo(accountKey)
            .deleteAll();
        await isar.signedAccountListings
            .where()
            .accountIdentifierEqualTo(accountKey)
            .deleteAll();
      });
    } catch (_) {}

    final p = await SharedPreferences.getInstance();
    final signedAccounts = p.getStringList('signed_accounts') ?? [];
    signedAccounts.remove(accountKey);
    await p.setStringList('signed_accounts', signedAccounts);
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

    final userIdStr = prefs.getString('userId') ?? '';
    final dbName = prefs.getString('dbName');
    final username = prefs.getString('username');
    final userLogin = prefs.getString('userLogin');
    final password = prefs.getString('password');

    final authLogin = userLogin ?? username;

    if (dbName == null ||
        authLogin == null ||
        password == null ||
        userIdStr.isEmpty)
      return;

    OdooClient client;
    try {
      client = await AuthService().getAuthenticatedClient(
        url: serverUrl,
        database: dbName,
        username: authLogin,
        password: password,
        sessionId: prefs.getString('session_id'),
        userId: int.tryParse(userIdStr) ?? 0,
        partnerId: int.tryParse(prefs.getString('partnerId') ?? '0') ?? 0,
        userLogin: userLogin,
        userName: prefs.getString('userName'),
        userLang: prefs.getString('userLang') ?? 'en_US',
        userTz: prefs.getString('userTz') ?? 'UTC',
        isSystem: prefs.getBool('isSystem') ?? false,
        serverVersion: prefs.getString('serverVersion') ?? '',
        companyId: int.tryParse(prefs.getString('companyId') ?? '1') ?? 1,
        twoFactorRequired: prefs.getBool('twoFactorRequired') ?? false,
      );
    } catch (e) {
      return;
    }

    try {
      final fieldsResponse = await client.callKw({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [],
        'kwargs': {
          'attributes': ['type'],
        },
      });
      final availableFields = fieldsResponse as Map<String, dynamic>;
      final mobileField =
          availableFields.containsKey('mobile')
              ? 'mobile'
              : (availableFields.containsKey('mobile_phone')
                  ? 'mobile_phone'
                  : null);

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
        if (widget.onProfilePictureUpdated != null &&
            ImageUtils.base64Of(profiles.first['image_1920']).isNotEmpty) {
          try {
            final imageData = ImageUtils.base64Of(profiles.first['image_1920']);
            if (imageData.isNotEmpty) {
              final bytes = base64Decode(imageData);
              if (ImageUtils.isValidImage(bytes)) {
                widget.onProfilePictureUpdated!(bytes);
              } else {}
            }
          } catch (e) {}
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
          toolbarHeight: kToolbarHeight, // 56, same as other Mobo apps
          elevation: 0,
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
              weight: FontWeight.bold,
              size: 20,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          // Without this, the Stack shrinks to the height of its scrollable
          // content instead of the full screen — leaving the area below the
          // content painted by the Scaffold's own background rather than by
          // the loading overlay below, so a switch-account tap only dims the
          // card area and leaves a visible plain strip beneath it.
          fit: StackFit.expand,
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
                          transitionDuration:
                              motionProvider.reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 300),
                          reverseTransitionDuration:
                              motionProvider.reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 300),
                          transitionsBuilder: (
                            context,
                            animation,
                            secondaryAnimation,
                            child,
                          ) {
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
                                              AppStyle.primaryColor,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ClipOval(
                                child:
                                    (profiles.isNotEmpty &&
                                            ImageUtils.base64Of(
                                              profiles.first['image_1920'],
                                            ).isNotEmpty)
                                        ? Builder(
                                          builder: (context) {
                                            try {
                                              final bytes = base64Decode(
                                                ImageUtils.base64Of(
                                                  profiles.first['image_1920'],
                                                ),
                                              );
                                              if (ImageUtils.isValidImage(
                                                bytes,
                                              )) {
                                                return ImageUtils.memory(
                                                  bytes,
                                                  width: 60,
                                                  height: 60,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) =>
                                                          _buildFallbackAvatar(),
                                                );
                                              }
                                            } catch (e) {}
                                            return _buildFallbackAvatar();
                                          },
                                        )
                                        : (widget.profileImageBytes != null &&
                                                ImageUtils.isValidImage(
                                                  widget.profileImageBytes,
                                                )
                                            ? ImageUtils.memory(
                                              widget.profileImageBytes!,
                                              width: 60,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => _buildFallbackAvatar(),
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    )
                                    : Text(
                                      profiles.isNotEmpty
                                          ? (profiles.first['email'] is String
                                              ? profiles.first['email']
                                              : "")
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
                              color:
                                  isDark
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
                                transitionDuration:
                                    motionProvider.reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 300),
                                reverseTransitionDuration:
                                    motionProvider.reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 300),
                                transitionsBuilder: (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
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
                              color:
                                  isDark
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
                              _accountsLoaded && _otherAccounts.isNotEmpty
                                  ? "${_otherAccounts.length} other account${_otherAccounts.length == 1 ? '' : 's'} available"
                                  : "Add multiple accounts to switch quickly",
                              style: AppStyle.font(
                                color:
                                    isDark
                                        ? Colors.grey[400]!
                                        : Colors.grey[600]!,
                              ),
                            ),
                            children: [
                              if (_otherAccounts.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: AppStyle.primaryColor
                                              .withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.person_add_alt_1,
                                          color: AppStyle.primaryColor,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "No Other Accounts",
                                        style: AppStyle.font(
                                          weight: FontWeight.w600,
                                          size: 15,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Add multiple accounts to switch between them quickly",
                                        textAlign: TextAlign.center,
                                        style: AppStyle.font(
                                          weight: FontWeight.w400,
                                          size: 13,
                                          color:
                                              isDark
                                                  ? Colors.grey[400]!
                                                  : Colors.grey[600]!,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ..._otherAccounts.map((user) {
                                Uint8List? avatar;
                                if (user['image'] != null &&
                                    user['image'] is String &&
                                    (user['image'] as String).isNotEmpty) {
                                  try {
                                    avatar = base64Decode(user['image']);
                                  } catch (_) {}
                                }
                                final displayName =
                                    (user['userName'] ?? user['username'] ?? '')
                                        .toString();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color:
                                        isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        setState(() {
                                          isLoading = true;
                                        });
                                        await switchAccount(user);
                                        if (mounted) {
                                          setState(() {
                                            isLoading = false;
                                          });
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipOval(
                                                child:
                                                    (avatar != null &&
                                                            ImageUtils.isValidImage(
                                                              avatar,
                                                            ))
                                                        ? ImageUtils.memory(
                                                          avatar,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (
                                                                context,
                                                                error,
                                                                stackTrace,
                                                              ) => const Icon(
                                                                Icons.person,
                                                              ),
                                                        )
                                                        : const Icon(
                                                          Icons.person,
                                                        ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    displayName,
                                                    style: AppStyle.font(
                                                      weight: FontWeight.w500,
                                                      size: 16,
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    (user['dbName'] ?? '')
                                                        .toString(),
                                                    style: AppStyle.font(
                                                      weight: FontWeight.w400,
                                                      size: 13,
                                                      color:
                                                          isDark
                                                              ? Colors
                                                                  .grey[400]!
                                                              : Colors
                                                                  .grey[600]!,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: Icon(
                                                Icons.more_vert,
                                                color:
                                                    isDark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                              ),
                                              onSelected: (value) {
                                                if (value == 'remove') {
                                                  _confirmAndRemoveAccount(
                                                    user,
                                                  );
                                                }
                                              },
                                              itemBuilder:
                                                  (context) => [
                                                    PopupMenuItem(
                                                      value: 'remove',
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color: Color(
                                                              0xFFD32F2F,
                                                            ),
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            'Remove',
                                                            style: AppStyle.font(
                                                              color:
                                                                  const Color(
                                                                    0xFFD32F2F,
                                                                  ),
                                                              size: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
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
                                          pageBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                              ) => const SwitchAccountScreen(),
                                          transitionDuration:
                                              motionProvider.reduceMotion
                                                  ? Duration.zero
                                                  : const Duration(
                                                    milliseconds: 300,
                                                  ),
                                          reverseTransitionDuration:
                                              motionProvider.reduceMotion
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
                                            if (motionProvider.reduceMotion)
                                              return child;
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                        ),
                                      ).then((_) {
                                        loadProfile();
                                        _loadOtherAccounts();
                                      });
                                    },
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedUserAdd01,
                                    ),
                                    label: Text(
                                      "Add Account",
                                      style: AppStyle.font(
                                        weight: FontWeight.w500,
                                        color:
                                            isDark
                                                ? Colors.black
                                                : Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                      foregroundColor:
                                          isDark ? Colors.black : Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
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
                          leading: const Icon(
                            Icons.logout,
                            color: Color(0xFFD32F2F),
                          ),
                          title: Text(
                            "Logout",
                            style: AppStyle.font(
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFFD32F2F),
                              weight: FontWeight.normal,
                              size: 16,
                            ),
                          ),
                          subtitle: Text(
                            "Sign out from this device",
                            style: AppStyle.font(
                              color:
                                  isDark
                                      ? Colors.grey[400]!
                                      : Colors.grey[600]!,
                            ),
                          ),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => LogoutDialog(
                                    storageService: storageService,
                                  ),
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

    final url = user['uri'] as String;
    final dbName = user['dbName'] as String;
    final userLogin = (user['userLogin'] ?? user['username']) as String;
    final password = user['password'] as String? ?? '';
    final storedSessionId = user['sessionId'] as String?;

    try {
      OdooSession? session;

      // Try to reuse the account's stored session first. This is critical
      // for 2FA-enabled accounts, which can never succeed a plain
      // password-only re-authentication — only a fresh TOTP handshake can.
      if (storedSessionId != null && storedSessionId.isNotEmpty) {
        try {
          final probeSession = OdooSession(
            id: storedSessionId,
            userId: int.tryParse(user['userId'].toString()) ?? 0,
            partnerId: int.tryParse(user['partnerId']?.toString() ?? '') ?? 0,
            userLogin: userLogin,
            userName:
                (user['userName'] ?? user['username'] ?? userLogin) as String,
            userLang: user['userLang'] as String? ?? 'en_US',
            userTz: user['userTimezone'] as String? ?? 'UTC',
            isSystem: user['isSystem'] as bool? ?? false,
            dbName: dbName,
            serverVersion: user['serverVersion'] as String? ?? '',
            companyId: int.tryParse(user['companyId']?.toString() ?? '') ?? 1,
            allowedCompanies: const [],
          );
          final probeClient = OdooClient(url, sessionId: probeSession);
          await probeClient.callKw({
            'model': 'res.users',
            'method': 'search_read',
            'args': [
              [
                ['id', '=', probeSession.userId],
              ],
            ],
            'kwargs': {
              'fields': ['id'],
              'limit': 1,
            },
          });
          session = probeSession;
        } catch (_) {
          session = null;
        }
      }

      if (session == null) {
        // Stored session is stale or missing — fall back to password auth.
        try {
          final client = OdooClient(url);
          session = await client.authenticate(dbName, userLogin, password);
        } catch (e) {
          final formatted = AuthService.formatLoginError(e);
          if (formatted == AuthService.genericSwitchAccountFailureMessage) {
            if (!mounted) return;
            // A password-auth failure with no recognizable error is assumed
            // to mean "this account has 2FA enabled" (see the doc comment on
            // genericSwitchAccountFailureMessage). But if the database itself
            // was deleted/renamed, that assumption is wrong and pushing to
            // TwoFactorAuthPage would just hang trying to load a database
            // that no longer exists — check first, matching mobo FullSuite's
            // ConfigurationScreen._databaseStillExists guard.
            final databaseExists = await _databaseStillExists(url, dbName);
            if (databaseExists == false) {
              if (mounted) await _showDatabaseUnavailableDialog(dbName);
              return;
            }
            if (!mounted) return;
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder:
                    (_) => TwoFactorAuthPage(
                      serverUrl: url,
                      database: dbName,
                      username: userLogin,
                      password: password,
                      onSuccessRouteName: '/backend',
                    ),
              ),
            );
            return;
          }
          rethrow;
        }
      }

      if (session == null) {
        throw Exception('Unable to authenticate this account.');
      }

      await AuthService().saveAuthenticatedSession(
        url: url,
        database: dbName,
        username: userLogin,
        password: password,
        sessionId: session.id,
        userId: session.userId,
        userLogin: session.userLogin,
        userName: session.userName,
        partnerId: session.partnerId,
        userLang: session.userLang,
        userTz: session.userTz,
        isSystem: session.isSystem,
        serverVersion: session.serverVersion,
        companyId: session.companyId,
        imageBase64: user['image'] as String? ?? '',
      );

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/backend',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              e is DatabaseExpiredException
                  ? DatabaseExpiredException.message
                  : "Failed to switch account: $e",
            ),
          ),
        );
      }
    }
  }

  /// Returns whether [dbName] is still listed on the server at [url], or
  /// `null` if that couldn't be determined (e.g. `list_db=false`) — in which
  /// case the caller should assume it still exists rather than block on an
  /// inconclusive check.
  Future<bool?> _databaseStillExists(String url, String dbName) async {
    try {
      final databases = await NetworkService().fetchDatabaseList(url);
      if (databases.isEmpty) return null;
      return databases.contains(dbName);
    } catch (_) {
      return null;
    }
  }

  Future<void> _showDatabaseUnavailableDialog(String dbName) async {
    if (!mounted) return;
    await AppDialogs.showInfo(
      context,
      title: 'Database Unavailable',
      message:
          'The database "$dbName" is no longer available on this server. '
          'It may have been deleted or renamed by your administrator.',
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[200],
      child: const Icon(Icons.person, size: 30, color: AppStyle.primaryColor),
    );
  }
}
