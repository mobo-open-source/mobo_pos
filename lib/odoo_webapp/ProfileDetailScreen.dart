import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:isar_community/isar.dart';
import '../Isarmodel/user_profile.dart';
import '../Isarmodel/Isar.dart';
import 'package:mobo_pos/odoo_webapp/backend.dart';
import '../ui/dialogs/app_dialogs.dart';
import '../widgets/full_image_screen.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final Uint8List? userAvatar;
  final VoidCallback? onProfileUpdated;

  const ProfileDetailScreen({
    super.key,
    this.userData,
    this.userAvatar,
    this.onProfileUpdated,
  });

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  Uint8List? _userAvatar;
  bool _isEditMode = false;
  bool _isSaving = false;
  File? _pickedImageFile;

  // String? _pickedImageBase64; // Commented out as it's not used in this implementation
  final ImagePicker _picker = ImagePicker();

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Text controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _functionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _userAvatar = widget.userAvatar;

    // If no userData passed, load from SharedPreferences
    if (_userData == null || _userData!.isEmpty) {
      _loadUserDataFromCache();
    } else {
      _debugPrintUserData();
      _updateControllers();
    }
  }

  Future<void> _loadUserDataFromCache() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString("username");
      final dbName = prefs.getString("dbName");
      final userId = prefs.getString("userId");

      if (username != null && dbName != null && userId != null) {
        // Load from Isar cache
        final accountKey = '$username@$dbName';
        final isar = await IsarService.instance;
        final cachedProfile =
            await isar.userProfiles
                .filter()
                .accountKeyEqualTo(accountKey)
                .findFirst();

        if (cachedProfile != null) {
          setState(() {
            _userData = {
              'id': int.tryParse(userId) ?? 0,
              'name': cachedProfile.userName ?? username,
              'email': cachedProfile.userEmail ?? '',
              'phone': cachedProfile.userPhone ?? '',
              'mobile': cachedProfile.userMobile ?? '',
              'website': cachedProfile.userWebsite ?? '',
              'function': cachedProfile.userFunction ?? '',
              'image_1920': cachedProfile.profileImageBase64 ?? '',
            };

            // Decode avatar if available
            if (cachedProfile.profileImageBase64 != null &&
                cachedProfile.profileImageBase64!.isNotEmpty) {
              try {
                _userAvatar = base64Decode(cachedProfile.profileImageBase64!);
              } catch (e) {
              }
            }

            _isLoading = false;
          });

          _debugPrintUserData();
          _updateControllers();
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _debugPrintUserData() {
    if (_userData != null) {
      _userData!.forEach((key, value) {
      });
    } else {
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _functionController.dispose();
    super.dispose();
  }

  String _normalizeForEdit(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : '';
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    if (s.toLowerCase() == 'false') return '';
    if (s.toLowerCase() == 'null') return ''; // Handle string "null"
    return s;
  }

  void _updateControllers() {
    if (_userData != null) {

      _nameController.text = _normalizeForEdit(_userData!['name']);
      _emailController.text = _normalizeForEdit(
        _userData!['email'] ?? _userData!['work_email'],
      );

      // Phone field - try multiple possible field names including partner fields
      final phoneValue =
          _userData!['phone'] ??
          _userData!['work_phone'] ??
          _userData!['work_phone_number'];
      _phoneController.text = _normalizeForEdit(phoneValue);

      // Mobile field - try multiple possible field names including partner fields
      final mobileValue =
          _userData!['mobile'] ??
          _userData!['work_mobile'] ??
          _userData!['partner_mobile'] ??
          _userData!['mobile_phone'] ??
          _userData!['cell_phone'] ??
          _userData!['personal_mobile'];
      _mobileController.text = _normalizeForEdit(mobileValue);

      // Website field - try multiple possible field names including partner fields
      final websiteValue =
          _userData!['website'] ??
          _userData!['work_website'] ??
          _userData!['partner_website'] ??
          _userData!['website_url'];
      _websiteController.text = _normalizeForEdit(websiteValue);

      // Function/Job Title field - try multiple possible field names including partner fields
      final functionValue =
          _userData!['function'] ??
          _userData!['job_title'] ??
          _userData!['partner_function'] ??
          _userData!['job_position'] ??
          _userData!['position'] ??
          _userData!['title'];
      _functionController.text = _normalizeForEdit(functionValue);


      // Verify controller values after setting
    }
  }

  void _cancelEdit() {
    _updateControllers();
    setState(() => _isEditMode = false);
  }

  bool _hasUnsavedChanges() {
    if (_userData == null) return false;

    return _nameController.text.trim() !=
            _normalizeForEdit(_userData!['name']) ||
        _emailController.text.trim() !=
            _normalizeForEdit(
              _userData!['email'] ?? _userData!['work_email'],
            ) ||
        _phoneController.text.trim() !=
            _normalizeForEdit(
              _userData!['work_phone'] ??
                  _userData!['phone'] ??
                  _userData!['work_phone_number'],
            ) ||
        _mobileController.text.trim() !=
            _normalizeForEdit(
              _userData!['mobile'] ??
                  _userData!['work_mobile'] ??
                  _userData!['mobile_phone'] ??
                  _userData!['cell_phone'] ??
                  _userData!['personal_mobile'],
            ) ||
        _websiteController.text.trim() !=
            _normalizeForEdit(
              _userData!['website'] ??
                  _userData!['work_website'] ??
                  _userData!['website_url'],
            ) ||
        _functionController.text.trim() !=
            _normalizeForEdit(
              _userData!['function'] ??
                  _userData!['job_title'] ??
                  _userData!['job_position'] ??
                  _userData!['position'] ??
                  _userData!['title'],
            );
  }

  Future<void> _saveAllChanges() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fix the validation errors before saving');
      return;
    }

    setState(() => _isSaving = true);
    _showLoadingDialog(context, 'Saving Changes');

    try {

      // Get current session data
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');
      final serverUrl = prefs.getString('uri');
      final dbName = prefs.getString('dbName');
      final userId = prefs.getString('userId');
      final partnerId = prefs.getString('partnerId');

      if (sessionId == null ||
          serverUrl == null ||
          dbName == null ||
          userId == null) {
        throw Exception('Missing session data. Please login again.');
      }

      // Use existing session instead of re-authenticating
      final userIdInt = int.tryParse(userId);
      final partnerIdInt = int.tryParse(partnerId ?? '0');
      final userLogin = prefs.getString('userLogin') ?? '';
      final userNameStored = prefs.getString('userName') ?? '';
      final userLang = prefs.getString('userLang') ?? 'en_US';
      final userTz = prefs.getString('userTz') ?? 'UTC';
      final isSystem = prefs.getBool('isSystem') ?? false;
      final serverVersion = prefs.getString('serverVersion') ?? '';
      final companyIdStored = int.tryParse(prefs.getString('companyId') ?? '0');

      if (sessionId == null || userIdInt == null || companyIdStored == null) {
        throw Exception('Session expired. Please login again.');
      }

      final session = OdooSession(
        id: sessionId,
        userId: userIdInt,
        partnerId: partnerIdInt ?? 0,
        userLogin: userLogin,
        userName: userNameStored,
        userLang: userLang,
        userTz: userTz,
        isSystem: isSystem,
        dbName: dbName,
        serverVersion: serverVersion,
        companyId: companyIdStored,
        allowedCompanies: [],
      );

      final client = OdooClient(serverUrl);

      // CRITICAL: Re-authenticate the client
      final username = prefs.getString("username");
      final password = prefs.getString("password");
      if (username != null && password != null) {
        await client.authenticate(dbName, username, password);
      }

      // Update user data in Odoo backend
      final userUpdates = <String, dynamic>{};
      if (_nameController.text.trim() !=
          _normalizeForEdit(_userData!['name'])) {
        userUpdates['name'] = _nameController.text.trim();
      }
      if (_emailController.text.trim() !=
          _normalizeForEdit(_userData!['email'])) {
        userUpdates['email'] = _emailController.text.trim();
      }
      if (_functionController.text.trim() !=
          _normalizeForEdit(
            _userData!['function'] ?? _userData!['job_title'],
          )) {
        userUpdates['function'] = _functionController.text.trim();
      }

      // Update partner data in Odoo backend (for phone, mobile, website)
      final partnerUpdates = <String, dynamic>{};
      if (_phoneController.text.trim() !=
          _normalizeForEdit(_userData!['phone'])) {
        partnerUpdates['phone'] = _phoneController.text.trim();
      }
      if (_mobileController.text.trim() !=
          _normalizeForEdit(
            _userData!['mobile'] ?? _userData!['partner_mobile'],
          )) {
        partnerUpdates['mobile'] = _mobileController.text.trim();
      }
      if (_websiteController.text.trim() !=
          _normalizeForEdit(
            _userData!['website'] ?? _userData!['partner_website'],
          )) {
        partnerUpdates['website'] = _websiteController.text.trim();
      }


      // Update user record if there are changes
      if (userUpdates.isNotEmpty) {
        await client.callKw({
          'model': 'res.users',
          'method': 'write',
          'args': [
            [userIdInt],
            userUpdates,
          ],
          'kwargs': {},
        });
      }

      // Update partner record if there are changes
      if (partnerUpdates.isNotEmpty && partnerId != null) {
        await client.callKw({
          'model': 'res.partner',
          'method': 'write',
          'args': [
            [int.parse(partnerId)],
            partnerUpdates,
          ],
          'kwargs': {},
        });
      }

      // Update local database
      await _updateLocalDatabase();

      // Update userData with new values
      _userData!['name'] = _nameController.text.trim();
      _userData!['email'] = _emailController.text.trim();
      _userData!['phone'] = _phoneController.text.trim();
      _userData!['mobile'] = _mobileController.text.trim();
      _userData!['work_mobile'] = _mobileController.text.trim();
      _userData!['website'] = _websiteController.text.trim();
      _userData!['work_website'] = _websiteController.text.trim();
      _userData!['function'] = _functionController.text.trim();
      _userData!['job_title'] = _functionController.text.trim();

      client.close();

      setState(() => _isEditMode = false);
      _showSuccessSnackBar('Profile updated successfully');

      // Call the callback to refresh parent widget
      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save changes: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _updateLocalDatabase() async {
    try {

      // Get current session data
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final dbName = prefs.getString('dbName');

      if (username == null || dbName == null) {
        return;
      }

      final accountKey = '$username@$dbName';
      final isar = await IsarService.instance;

      // Find existing user profile
      final existingProfile =
          await isar.userProfiles
              .filter()
              .accountKeyEqualTo(accountKey)
              .findFirst();

      if (existingProfile != null) {
        // Update existing profile
        existingProfile.userName = _nameController.text.trim();
        existingProfile.userEmail = _emailController.text.trim();
        existingProfile.userPhone = _phoneController.text.trim();
        existingProfile.userMobile = _mobileController.text.trim();
        existingProfile.userWebsite = _websiteController.text.trim();
        existingProfile.userFunction = _functionController.text.trim();
        existingProfile.lastUpdated = DateTime.now();

        await isar.writeTxn(() async {
          await isar.userProfiles.put(existingProfile);
        });

      } else {
      }

    } catch (e) {
      // Don't throw error - local database update is not critical
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isDark ? const Color(0xFF212121) : Colors.white,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.12)
                              : const Color(0xFF1E88E5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we process your request',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      setState(() => _pickedImageFile = File(picked.path));
      // final bytes = await picked.readAsBytes(); // Would be used for image processing
      if (!mounted) return;

      // Image processing would go here in a full implementation

      if (mounted) {
        _showSuccessSnackBar('Image updated successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update image: $e');
      }
    }
  }

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera02,
                          size: 24,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Take Photo',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedImageCrop,
                          size: 24,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Choose from Gallery',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Future<void> _handleBack() async {
    if (_isEditMode && _hasUnsavedChanges()) {
      final shouldPop = await _showUnsavedChangesDialog();
      if (shouldPop && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final result = await AppDialogs.showConfirm(
      context,
      title: 'Discard Changes?',
      message:
          'You have unsaved changes that will be lost if you leave this page. Are you sure you want to discard these changes?',
      confirmText: 'Discard',
      cancelText: 'Keep Editing',
      isDestructive: true,
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900]! : Colors.grey[50]!,
        appBar: AppBar(
          title: Text(
            'Profile Details',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            onPressed: () async {
              await _handleBack();
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          actions: [
            if (_isEditMode)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: _isSaving ? null : _cancelEdit,
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 0.0),
              child: TextButton(
                onPressed:
                    _isSaving
                        ? null
                        : () {
                          if (_isEditMode) {
                            _saveAllChanges();
                          } else {
                            setState(() => _isEditMode = true);
                          }
                        },
                child: Text(
                  _isEditMode ? 'Save' : 'Edit',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color:
                        _isEditMode
                            ? (isDark ? Colors.white : Colors.black)
                            : isDark
                            ? Colors.white
                            : const Color(0xFFC03355),
                  ),
                ),
              ),
            ),
          ],
          backgroundColor: isDark ? Colors.grey[900]! : Colors.grey[50]!,
          systemOverlayStyle:
              isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userData == null
                ? const Center(child: Text('No user data found'))
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile fields section
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Image Section
                              _buildProfileImageSection(context, isDark),
                              const SizedBox(height: 32),

                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildCustomTextField(
                                context,
                                'Full Name',
                                _userData!['name']?.toString(),
                                HugeIcons.strokeRoundedUserAccount,
                                controller: _nameController,
                              ),
                              const SizedBox(height: 16),
                              _buildCustomTextField(
                                context,
                                'Email',
                                _userData!['email']?.toString(),
                                HugeIcons.strokeRoundedMail01,
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                showNonEditableMessage: true,
                              ),
                              const SizedBox(height: 16),
                              _buildCustomTextField(
                                context,
                                'Phone',
                                (_userData!['work_phone'] ??
                                        _userData!['phone'] ??
                                        _userData!['work_phone_number'])
                                    ?.toString(),
                                HugeIcons.strokeRoundedCall02,
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              _buildCustomTextField(
                                context,
                                'Mobile',
                                (_userData!['mobile'] ??
                                        _userData!['work_mobile'] ??
                                        _userData!['mobile_phone'] ??
                                        _userData!['cell_phone'] ??
                                        _userData!['personal_mobile'])
                                    ?.toString(),
                                HugeIcons.strokeRoundedSmartPhone01,
                                controller: _mobileController,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              _buildCustomTextField(
                                context,
                                'Website',
                                (_userData!['website'] ??
                                        _userData!['work_website'] ??
                                        _userData!['website_url'])
                                    ?.toString(),
                                HugeIcons.strokeRoundedWebDesign02,
                                controller: _websiteController,
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 16),
                              _buildCustomTextField(
                                context,
                                'Job Title',
                                (_userData!['function'] ??
                                        _userData!['job_title'] ??
                                        _userData!['job_position'] ??
                                        _userData!['position'] ??
                                        _userData!['title'])
                                    ?.toString(),
                                HugeIcons.strokeRoundedWorkHistory,
                                controller: _functionController,
                              ),
                              const SizedBox(height: 16),
                              _buildCustomTextField(
                                context,
                                'Company',
                                _userData!['company_id'] is List &&
                                        _userData!['company_id'].length > 1
                                    ? (_userData!['company_id'][1]
                                            ?.toString() ??
                                        '')
                                    : '',
                                HugeIcons.strokeRoundedBuilding05,
                                showNonEditableMessage: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildCustomTextField(
    BuildContext context,
    String labelText,
    String? value,
    List<List<dynamic>> icon, {
    VoidCallback? onEdit,
    bool disabled = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    bool showNonEditableMessage = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue =
        (value == null ||
                value.trim().isEmpty ||
                value.trim().toLowerCase() == 'false')
            ? 'Not set'
            : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        _isEditMode && controller != null && !disabled
            ? _buildEditableField(
              context,
              controller,
              keyboardType,
              labelText,
              isDark,
            )
            : _buildDisplayField(
              context,
              displayValue,
              icon,
              isDark,
              onEdit: onEdit,
              labelText: labelText,
              showNonEditableMessage: showNonEditableMessage,
            ),
      ],
    );
  }

  Widget _buildDisplayField(
    BuildContext context,
    String displayValue,
    List<List<dynamic>> icon,
    bool isDark, {
    VoidCallback? onEdit,
    String? labelText,
    bool showNonEditableMessage = false,
  }) {
    return GestureDetector(
      onTap:
          onEdit ??
          (showNonEditableMessage && labelText != null
              ? () {
                if (mounted) {
                  _showErrorSnackBar(
                    '$labelText cannot be modified from this screen',
                  );
                }
              }
              : null),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
          border: Border.all(color: Colors.transparent, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color:
                        displayValue == 'Not set'
                            ? (isDark ? Colors.grey[500] : Colors.grey[500])
                            : (isDark
                                ? Colors.white70
                                : const Color(0xff000000)),
                    fontStyle:
                        displayValue == 'Not set'
                            ? FontStyle.italic
                            : FontStyle.normal,
                    fontSize: 14,
                    height: 1.2,
                    letterSpacing: 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
    BuildContext context,
    TextEditingController controller,
    TextInputType? keyboardType,
    String labelText,
    bool isDark,
  ) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color:
                      isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xffF8FAFB),
                  border: Border.all(
                    color:
                        hasFocus
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: _getIconForField(labelText),
                        color:
                            isDark ? Colors.white70 : const Color(0xff7F7F7F),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: keyboardType,
                          validator: _getValidatorForField(labelText),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          style: TextStyle(
                            color:
                                isDark
                                    ? Colors.white70
                                    : const Color(0xff000000),
                            fontSize: 14,
                            height: 1.2,
                            letterSpacing: 0.0,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            hintText:
                                controller.text.isEmpty
                                    ? 'Enter $labelText'
                                    : null,
                            hintStyle: TextStyle(
                              color:
                                  isDark ? Colors.grey[500] : Colors.grey[500],
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              height: 1.2,
                              letterSpacing: 0.0,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            errorStyle: const TextStyle(height: 0, fontSize: 0),
                          ),
                          cursorColor: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_getValidatorForField(labelText) != null)
                _buildErrorMessage(controller, labelText, isDark),
            ],
          );
        },
      ),
    );
  }

  List<List<dynamic>> _getIconForField(String labelText) {
    switch (labelText.toLowerCase()) {
      case 'full name':
        return HugeIcons.strokeRoundedUserAccount;
      case 'email':
        return HugeIcons.strokeRoundedMail01;
      case 'phone':
        return HugeIcons.strokeRoundedCall02;
      case 'mobile':
        return HugeIcons.strokeRoundedSmartPhone01;
      case 'website':
        return HugeIcons.strokeRoundedWebDesign02;
      case 'job title':
        return HugeIcons.strokeRoundedWorkHistory;
      case 'company':
        return HugeIcons.strokeRoundedBuilding05;
      default:
        return HugeIcons.strokeRoundedUserAccount;
    }
  }

  String? Function(String?)? _getValidatorForField(String labelText) {
    switch (labelText.toLowerCase()) {
      case 'email':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegex.hasMatch(value.trim())) {
            return 'Please enter a valid email address';
          }
          return null;
        };
      case 'website':
        return (value) {
          if (value == null || value.trim().isEmpty) return null;
          final urlRegex = RegExp(
            r'^(https?:\/\/)?(www\.)?[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+(\/.*)?$',
          );
          if (!urlRegex.hasMatch(value.trim())) {
            return 'Please enter a valid website URL';
          }
          return null;
        };
      default:
        return null;
    }
  }

  Widget _buildErrorMessage(
    TextEditingController controller,
    String labelText,
    bool isDark,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final validator = _getValidatorForField(labelText);
        final errorMessage = validator?.call(value.text);
        if (errorMessage == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            errorMessage,
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileImageSection(BuildContext context, bool isDark) {
    // Create photo widget
    Widget photoWidget;
    if (_pickedImageFile != null) {
      photoWidget = ClipOval(
        child: Image.file(
          _pickedImageFile!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else if (_userAvatar != null) {
      photoWidget = ClipOval(
        child: Image.memory(
          _userAvatar!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      );
    } else {
      final placeholderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
      photoWidget = Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: placeholderColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: 60,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      );
    }

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap:
                (!_isEditMode && _userAvatar != null)
                    ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => FullImageScreen(
                                title: 'Profile Photo',
                                imageBytes: _userAvatar!,
                                imageName:
                                    _userData?['name']?.toString() ?? 'User',
                              ),
                        ),
                      );
                    }
                    : null,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: photoWidget,
                ),
                if (_isEditMode)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: InkWell(
                      onTap: _showImageSourceActionSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC03355),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.grey[900]! : Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          if (_normalizeForEdit(_userData!['name']).isNotEmpty)
            Text(
              '${_normalizeForEdit(_userData!['name'])}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.grey[400] : Colors.grey[800],
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
