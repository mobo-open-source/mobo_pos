import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../core/style.dart';
import '../shared/widgets/snackbar.dart';
import '../services/profile_service.dart';
import '../services/reset_password_service.dart';

class ProfileFormPage extends StatefulWidget {
  final Future<void> Function()? refreshProfile;

  const ProfileFormPage({super.key, this.refreshProfile});

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  List<Profile> profiles = [];
  Uint8List? profileImageBytes;
  String? base64Image;
  File? _pickedImageFile;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyController = TextEditingController();
  final _mobileController = TextEditingController();
  bool mobileSupported = true;
  final _websiteController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _picker = ImagePicker();
  bool isEdited = false;
  final _street1Controller = TextEditingController();
  final _street2Controller = TextEditingController();
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  int parseMajorVersion(String? serverVersion) {
    if (serverVersion == null || serverVersion.isEmpty) return 0;
    final match = RegExp(r'(\d{1,2})').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> loadProfile() async {
    try {
      final profileService = ProfileService();
      await profileService.initializeClient();
      profiles = await profileService.loadProfile();
      mobileSupported = await profileService.mobileTarget() != null;
      if (profiles.isNotEmpty) {
        final profile = profiles.first;
        _nameController.text = profile.name;
        _emailController.text = profile.mail;
        _phoneController.text = profile.phone;
        _addressController.text = profile.address;
        _companyController.text = profile.company;
        _mobileController.text = profile.mobile;
        _websiteController.text = profile.website;
        _jobTitleController.text = profile.jobTitle;
        _street1Controller.text = profile.street;
        _street2Controller.text = profile.street2;

        if (profile.image.isNotEmpty) {
          try {
            final bytes = base64Decode(profile.image);
            var valid = _isSvg(bytes);
            if (!valid) {
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              valid = frame.image.width > 0 && frame.image.height > 0;
            }
            if (valid) {
              if (mounted) {
                setState(() {
                  profileImageBytes = bytes;
                });
              }
              // The generated SVG avatar is only for display - never write
              // it back to the user as an uploaded photo on Save.
              if (!_isSvg(bytes)) base64Image = profile.image;
            }
          } catch (e) {}
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Unable to load profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  bool _isSvg(Uint8List bytes) {
    final head = String.fromCharCodes(bytes.take(256)).trimLeft();
    return head.startsWith('<svg') || head.startsWith('<?xml');
  }

  Future<void> _pickImage() async {
    try {
      final profileService = ProfileService();
      await profileService.initializeClient();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        final base64String = base64Encode(bytes);
        if (mounted) {
          setState(() {
            profileImageBytes = bytes;
            base64Image = base64String;
            isEdited = true;
          });
        }
        await profileService.updateUserProfile({'image_1920': base64String});
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Unable to update photo: $e');
      }
    }
  }

  String? _validateName(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Full name is required';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!ResetPasswordService.isValidEmail(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    final validationError = _validateName(_nameController.text) ??
        _validateEmail(_emailController.text);
    if (validationError != null) {
      CustomSnackbar.showError(context, validationError);
      return;
    }
    setState(() {
      isSaving = true;
    });
    try {
      final profileService = ProfileService();
      await profileService.initializeClient();
      // 'name'/'email'/'image_1920' are in res.users' self-write whitelist,
      // so they can be written directly there. 'phone'/'mobile' aren't —
      // Odoo raises AccessError for a non-admin user writing them via
      // res.users even though they exist on it as related fields — so they
      // must go through res.partner instead (see ProfileService).
      final userUpdateData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'image_1920': base64Image ?? "",
      };
      final partnerUpdateData = {
        'phone': _phoneController.text.trim(),
        'mobile': _mobileController.text.trim(),
      };

      bool userSuccess = false;
      String? userErrorDetail;
      try {
        userSuccess = await profileService.updateUserProfile(userUpdateData);
      } catch (e) {
        userErrorDetail = e.toString();
      }

      bool partnerSuccess = false;
      String? partnerErrorDetail;
      try {
        partnerSuccess = await profileService.updatePartner(partnerUpdateData);
      } catch (e) {
        partnerErrorDetail = e.toString();
      }

      if (!mounted) return;
      if (userSuccess && partnerSuccess) {
        setState(() {
          isEdited = false;
        });
        CustomSnackbar.showSuccess(context, 'Profile saved successfully');
      } else if (userSuccess) {
        setState(() {
          isEdited = false;
        });
        CustomSnackbar.showError(
          context,
          'Profile saved, but phone/mobile could not be updated: '
          '${partnerErrorDetail ?? 'unknown error'}',
        );
      } else {
        CustomSnackbar.showError(
          context,
          'Failed to save profile: ${userErrorDetail ?? 'unknown error'}',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to save profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _jobTitleController.dispose();
    _street1Controller.dispose();
    _street2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await widget.refreshProfile?.call();
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900]! : Colors.white,
        appBar: AppBar(
          toolbarHeight: kToolbarHeight,
          backgroundColor: isDark ? Colors.grey[900]! : Colors.white,
          // Material 3 tints the app bar when content scrolls under it;
          // keep it flat so it matches the page background.
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text(
            'Profile Details',
            style: AppStyle.font(
              weight: FontWeight.bold,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (widget.refreshProfile != null) widget.refreshProfile!();
            },
          ),
          actions: [
            if (isEdited == false)
              TextButton(
                onPressed: () {
                  setState(() => isEdited = true);
                },
                child: Text(
                  "Edit",
                  style: AppStyle.font(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    weight: FontWeight.w600,
                    size: 15,
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => isEdited = false);
                    },
                    child: Text(
                      "Cancel",
                      style: AppStyle.font(
                        color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        weight: FontWeight.w500,
                        size: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isEdited ? _saveProfile : null,
                    child: Text(
                      "Save",
                      style: AppStyle.font(
                        color: isDark ? Colors.white : Colors.black,
                        weight: FontWeight.w600,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body:
            isLoading
                ? _buildShimmerLoading()
                : Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: isEdited ? _pickImage : null,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? Colors.grey[600]!
                                                : Colors.grey[300]!,
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
                                    child: ClipOval(
                                      child:
                                          profileImageBytes != null
                                              ? _isSvg(profileImageBytes!)
                                                  ? SvgPicture.memory(
                                                    profileImageBytes!,
                                                    width: 120,
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                  )
                                                  : Image.memory(
                                                profileImageBytes!,
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                              )
                                              : Container(
                                                width: 120,
                                                height: 120,
                                                color:
                                                    isDark
                                                        ? Colors.grey[700]
                                                        : Colors.grey[300],
                                                child: Icon(
                                                  Icons.person,
                                                  size: 60,
                                                  color:
                                                      isDark
                                                          ? Colors.grey[500]
                                                          : Colors.grey[600],
                                                ),
                                              ),
                                    ),
                                  ),
                                  if (isEdited)
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
                                            color: AppStyle.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  isDark
                                                      ? Colors.grey[900]!
                                                      : Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.2,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const HugeIcon(
                                            icon:
                                                HugeIcons.strokeRoundedCamera02,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_nameController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                _nameController.text.trim(),
                                textAlign: TextAlign.center,
                                style: AppStyle.font(
                                  size: 15,
                                  weight: FontWeight.w400,
                                  color:
                                      isDark
                                          ? Colors.grey[400]!
                                          : Colors.grey[800]!,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          Text(
                            "Personal Information",
                            style: AppStyle.font(
                              size: 18,
                              color: isDark ? Colors.white : Colors.black,
                              weight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoField(
                            HugeIcons.strokeRoundedUserAccount,
                            "Full Name",
                            _nameController,
                            validator: _validateName,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoField(
                            HugeIcons.strokeRoundedMail01,
                            "Email",
                            _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoField(
                            HugeIcons.strokeRoundedCall02,
                            "Phone",
                            _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\-\s()]'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (mobileSupported) ...[
                          _buildInfoField(
                            HugeIcons.strokeRoundedSmartPhone01,
                            "Mobile",
                            _mobileController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\-\s()]'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ],
                          _buildReadOnlyTextField(
                            HugeIcons.strokeRoundedWebDesign02,
                            "Website",
                            _websiteController,
                          ),
                          const SizedBox(height: 16),
                          _buildReadOnlyTextField(
                            HugeIcons.strokeRoundedWorkHistory,
                            "Job Title",
                            _jobTitleController,
                          ),
                          const SizedBox(height: 16),
                          _buildReadOnlyTextField(
                            HugeIcons.strokeRoundedBuilding05,
                            "Company",
                            _companyController,
                          ),
                        ],
                      ),
                    ),
                    if (isSaving)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black12,
                          child: Center(
                            child: LoadingAnimationWidget.fourRotatingDots(
                              color:
                                  isDark ? Colors.white : AppStyle.primaryColor,
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
                        Text(
                          'Take Photo',
                          style: AppStyle.font(
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
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
                        Text(
                          'Choose from Gallery',
                          style: AppStyle.font(
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
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

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        profileImageBytes = bytes;
        base64Image = base64Encode(bytes);
        isEdited = true;
      });

      CustomSnackbar.showSuccess(context, 'Image updated successfully');
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to update image: $e');
    }
  }

  Widget _buildInfoField(
    List<List<dynamic>> icon,
    String label,
    TextEditingController controller, {
    bool editable = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue =
        (controller.text.isEmpty) ? "Not set" : controller.text;

    if (isEdited && editable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppStyle.font(
              weight: FontWeight.w400,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? Colors.grey[850]! : const Color(0xFFF2F4F6),
            ),
                        child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              validator: validator,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: AppStyle.font(
                size: 15,
                weight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF101010),
              ),
              cursorColor: AppStyle.primaryColor,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: HugeIcon(
                    icon: icon,
                    color: isDark ? Colors.white70 : Colors.black,
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppStyle.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppStyle.font(
              weight: FontWeight.w400,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
          const SizedBox(height: 8),
          Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? Colors.grey[850]! : const Color(0xFFF2F4F6),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: icon,
                  color: isDark ? Colors.white70 : Colors.black,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayValue,
                    style: AppStyle.font(
                      size: 15,
                      color:
                          displayValue == 'Not set'
                              ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                              : (isDark ? Colors.white70 : Colors.black),
                      weight:
                          displayValue == "Not set"
                              ? FontWeight.w400
                              : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildReadOnlyTextField(
    List<List<dynamic>> icon,
    String label,
    TextEditingController controller,
  ) {
    final displayValue =
        (controller.text.isEmpty) ? "Not set" : controller.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppStyle.font(
            weight: FontWeight.w400,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? Colors.grey[850]! : const Color(0xFFF2F4F6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                color: isDark ? Colors.white70 : Colors.black,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayValue,
                  style: AppStyle.font(
                    size: 15,
                    color:
                        displayValue == 'Not set'
                            ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                            : (isDark ? Colors.white70 : Colors.black),
                    weight:
                        displayValue == "Not set"
                            ? FontWeight.w400
                            : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            const CircleAvatar(radius: 50),
            const SizedBox(height: 20),
            for (int i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
