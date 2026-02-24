import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../core/style.dart';
import '../shared/widgets/snackbar.dart';
import '../services/profile_service.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final profileService = ProfileService();
    await profileService.initializeClient();
    profiles = await profileService.loadProfile();
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
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          if (frame.image.width > 0 && frame.image.height > 0) {
            setState(() {
              profileImageBytes = bytes;
            });
            base64Image = profile.image;
          }
        } catch (e) {}
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final profileService = ProfileService();
    await profileService.initializeClient();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        profileImageBytes = bytes;
        base64Image = base64String;
        isEdited = true;
      });
      await profileService.updateUserProfile({'image_1920': base64String});
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      isSaving = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final profileService = ProfileService();
    await profileService.initializeClient();
    final fieldsResponse = await profileService.client!.callKw({
      'model': 'res.users',
      'method': 'fields_get',
      'args': [],
      'kwargs': {'attributes': ['type']}
    });
    final availableFields = fieldsResponse as Map<String, dynamic>;
    final mobileField = availableFields.containsKey('mobile')
        ? 'mobile'
        : (availableFields.containsKey('mobile_phone') ? 'mobile_phone' : null);

    final updateData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'contact_address': _addressController.text.trim(),
      if (mobileField != null) mobileField: _mobileController.text.trim(),
      'image_1920': base64Image ?? "",
    };
    final success = await profileService.updateUserProfile(updateData);
    if (success) {
      setState(() {
        isEdited = false;
        isSaving = false;
      });
      CustomSnackbar.showSuccess(context, 'Profile saved successfully');
    } else {
      setState(() {
        isEdited = false;
        isSaving = false;
      });
      CustomSnackbar.showError(context, 'Failed to save profile');
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
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          title: Text(
            'Profile Details',
            style: AppStyle.font(
              weight: FontWeight.w600,
              size: 22,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
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
          actions: [
            if (isEdited == false)
              TextButton(
                onPressed: () {
                  setState(() => isEdited = true);
                },
                child: Text(
                  "Edit",
                  style: AppStyle.font(
                    color: isDark ? Colors.white : Colors.black,
                    weight: FontWeight.w500,
                    size: 17,
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
                        color: isDark ? Colors.white70 : Colors.black54,
                        weight: FontWeight.w500,
                        size: 17,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isEdited ? _saveProfile : null,
                    child: Text(
                      "Save",
                      style: AppStyle.font(
                        color: AppStyle.primaryColor,
                        weight: FontWeight.w500,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: isLoading
            ? _buildShimmerLoading()
            : Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: isEdited ? _pickImage : null,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                            ClipOval(
                              child: profileImageBytes != null
                                      ? Image.memory(
                                          profileImageBytes!,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 100,
                                          height: 100,
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.person,
                                            size: 50,
                                            color: Colors.grey,
                                          ),
                                        ),
                            ),
                          if (isEdited)
                            Positioned(
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
                                      color: isDark
                                          ? Colors.grey[900]!
                                          : Colors.white,
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
                                  child: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedCamera02,
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
                  const SizedBox(height: 20),
                  Text(
                    "Personal Information",
                    style: AppStyle.font(
                      size: 16,
                      color: isDark ? Colors.white : Colors.black,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoField(
                    Icons.person_outline,
                    "Full Name",
                    _nameController,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoField(
                    Icons.email_outlined,
                    "Email",
                    _emailController,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoField(
                    Icons.phone_outlined,
                    "Phone",
                    _phoneController,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoField(
                    Icons.phone_android_outlined,
                    "Mobile",
                    _mobileController,
                  ),
                  const SizedBox(height: 8),
                  _buildReadOnlyTextField(
                    Icons.language_outlined,
                    "Website",
                    _websiteController,
                  ),
                  const SizedBox(height: 8),
                  _buildReadOnlyTextField(
                    Icons.work_outline,
                    "Job Title",
                    _jobTitleController,
                  ),
                  const SizedBox(height: 8),
                  _buildReadOnlyTextField(
                    Icons.apartment_outlined,
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

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => SafeArea(
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
      IconData icon,
      String label,
      TextEditingController controller, {
        bool editable = true,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = (controller.text.isEmpty) ? "Not set" : controller.text;

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
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: TextFormField(
              controller: controller,
              style: AppStyle.font(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                prefixIcon: Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                ),
                border: InputBorder.none,
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
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayValue,
                    style: AppStyle.font(
                      size: 15,
                      color: displayValue == 'Not set'
                          ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                          : (isDark ? Colors.white70 : Colors.black),
                      weight: displayValue == "Not set"
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
      IconData icon,
      String label,
      TextEditingController controller,
      ) {
    final displayValue = (controller.text.isEmpty) ? "Not set" : controller.text;
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
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayValue,
                  style: AppStyle.font(
                    size: 15,
                    color: displayValue == 'Not set'
                        ? (isDark ? Colors.grey[500]! : Colors.grey[500]!)
                        : (isDark ? Colors.white70 : Colors.black),
                    weight: displayValue == "Not set"
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
