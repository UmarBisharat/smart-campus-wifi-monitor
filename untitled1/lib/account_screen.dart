import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthController authController = Get.find();
  final ImagePicker imagePicker = ImagePicker();

  String? imagePath;

  @override
  void initState() {
    super.initState();
    loadProfileImage();
  }

  // LOAD PROFILE IMAGE
  Future<void> loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedImagePath = prefs.getString('profileImage');

    if (savedImagePath != null && savedImagePath.isNotEmpty) {
      if (mounted) {
        setState(() {
          imagePath = savedImagePath;
        });
      }
    }
  }

  // PICK IMAGE
  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedImage == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImage', pickedImage.path);

      if (mounted) {
        setState(() {
          imagePath = pickedImage.path;
        });
      }

      Get.snackbar(
        'Profile Picture',
        'Profile picture updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Unable to select image',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // REMOVE IMAGE
  Future<void> removeImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profileImage');

    if (mounted) {
      setState(() {
        imagePath = null;
      });
    }

    Get.snackbar(
      'Profile Picture',
      'Profile picture removed',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // REMOVE IMAGE CONFIRMATION
  void showRemoveImageDialog() {
    Get.defaultDialog(
      title: 'Remove Profile Picture',
      middleText: 'Are you sure you want to remove your profile picture?',
      textCancel: 'Cancel',
      textConfirm: 'Remove',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onCancel: () {},
      onConfirm: () async {
        await removeImage();
      },
    );
  }

  // IMAGE OPTIONS
  void showImageOptions() {
    final colorScheme = Theme.of(context).colorScheme;

    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color ?? colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profile Picture',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 20),

              // TAKE PHOTO
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondary,
                  child: Icon(Icons.camera_alt, color: colorScheme.primary),
                ),
                title: const Text('Take Photo', style: TextStyle(fontSize: 16)),
                subtitle: const Text('Take a new profile picture'),
                onTap: () {
                  Get.back();
                  pickImage(ImageSource.camera);
                },
              ),

              // GALLERY
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondary,
                  child: Icon(Icons.photo_library, color: colorScheme.primary),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontSize: 16),
                ),
                subtitle: const Text('Select a picture from your device'),
                onTap: () {
                  Get.back();
                  pickImage(ImageSource.gallery);
                },
              ),

              // REMOVE PICTURE
              if (imagePath != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEEEE),
                    child: Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text(
                    'Remove Picture',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text('Remove your current profile picture'),
                  onTap: () {
                    Get.back();
                    showRemoveImageDialog();
                  },
                ),

              const Divider(),

              // CANCEL
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.close, color: Colors.white),
                ),
                title: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Get.back();
                },
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // LOGOUT CONFIRMATION
  void showLogoutDialog() {
    bool isLoggingOut = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: isLoggingOut ? null : () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoggingOut
                    ? null
                    : () async {
                  setState(() {
                    isLoggingOut = true;
                  });

                  await Future.delayed(const Duration(milliseconds: 100));
                  await Future.delayed(const Duration(seconds: 4));

                  authController.logout();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoggingOut
                      ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text('Logout', key: ValueKey('label')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // DELETE CURRENT ACCOUNT
  void showDeleteAccountDialog() {
    bool isDeleting = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Are you sure you want to delete your account?\n\n'
                  'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                  setState(() {
                    isDeleting = true;
                  });

                  await Future.delayed(const Duration(milliseconds: 100));
                  await Future.delayed(const Duration(seconds: 4));

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('profileImage');

                  await authController.deleteAccount();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isDeleting
                      ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text('Delete', key: ValueKey('label')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          authController.getName(),
          authController.getEmail(),
        ]),
        builder: (context, snapshot) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !snapshot.hasData
                ? const Center(
              key: ValueKey('loading'),
              child: CircularProgressIndicator(),
            )
                : _AccountContent(
              key: const ValueKey('content'),
              name: snapshot.data![0],
              email: snapshot.data![1],
              imagePath: imagePath,
              onShowImageOptions: showImageOptions,
              onLogout: showLogoutDialog,
              onDeleteAccount: showDeleteAccountDialog,
            ),
          );
        },
      ),
    );
  }
}

// ACCOUNT CONTENT
class _AccountContent extends StatelessWidget {
  final String name;
  final String email;
  final String? imagePath;
  final VoidCallback onShowImageOptions;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const _AccountContent({
    super.key,
    required this.name,
    required this.email,
    required this.imagePath,
    required this.onShowImageOptions,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bool hasImage = imagePath != null && File(imagePath!).existsSync();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // PROFILE IMAGE
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: colorScheme.secondary,
                backgroundImage: hasImage ? FileImage(File(imagePath!)) : null,
                child: !hasImage
                    ? Icon(Icons.person, size: 65, color: colorScheme.primary)
                    : null,
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: onShowImageOptions,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: onShowImageOptions,
            child: const Text('Change Profile Picture'),
          ),

          const SizedBox(height: 8),

          // NAME
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 5),

          // EMAIL
          Text(
            email,
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),

          const SizedBox(height: 35),

          // ACCOUNT INFORMATION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Icon(Icons.person_outline, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Icon(Icons.email_outlined, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // LOGOUT
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: onLogout,
            ),
          ),

          const SizedBox(height: 15),

          // DELETE ACCOUNT
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text(
                'Delete Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: onDeleteAccount,
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}