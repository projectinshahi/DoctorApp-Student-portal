

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/app_size.dart';
import '../../../core/theam /app_color.dart';
import '../../../repository/profile_provider.dart';
import '../../../repository/refresh_api_provider.dart';
import '../../../widget/profile_shimmer.dart';
import '../../Authendication/login/login_screen.dart';
import '../Qbank/bookmarks_screen.dart';
import '../../../core/utils/refresh_on_visible.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RefreshOnVisible<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _fieldsInitialized = false;

  @override
  void initState() {
    super.initState();
    // The refresh itself is the mixin's job; this only exists because the
    // edit fields have to be re-seeded from whatever came back.
  }

  @override
  Future<void> onRefresh() async {
    await context.read<ProfileProvider>().loadProfile();
    if (!mounted) return;
    _syncControllersFromProfile();
  }

  void _syncControllersFromProfile() {
    final profile = context.read<ProfileProvider>().profile;
    if (profile != null && !_fieldsInitialized) {
      _nameController.text = profile.name ?? '';
      _phoneController.text = profile.phone ?? '';
      _fieldsInitialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto(ProfileProvider provider) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    final success = await provider.uploadAndSavePhoto(File(pickedFile.path));

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    }
  }

  Future<void> _openEditProfileDialog(ProfileProvider provider) async {
    // Reset fields to current saved values each time the dialog opens
    _nameController.text = provider.profile?.name ?? '';
    _phoneController.text = provider.profile?.phone ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: const Text(
                "Edit profile",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.errorMessage != null) ...[
                    Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12.5),
                    ),
                    SizedBox(height: 10.h),
                  ],
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Display name",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: provider.isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                    final success = await provider.saveProfile(
                      name: _nameController.text.trim(),
                      phone: _phoneController.text.trim(),
                    );
                    setDialogState(() {}); // reflect isSaving/errorMessage changes
                    if (success && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.Textcolor,
                    foregroundColor: Colors.white,
                  ),
                  child: provider.isSaving
                      ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Log out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Log out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await context.read<AuthProvider>().signOut();
    } catch (_) {
      // Even on error, force navigation to login so the user isn't stuck
    }

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      body: SafeArea(
        child: Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const ProfileShimmer();
            }

            if (provider.profile == null) {
              return Center(
                child: Text(provider.errorMessage ?? 'Failed to load profile'),
              );
            }

            _syncControllersFromProfile();
            final profile = provider.profile!;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Image.asset(
                          'asset/icons/Backarrow.png',
                          width: AppSize.iconBackArrowWidth,
                          height: AppSize.iconBackArrowHeight,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "profile",
                        style: TextStyle(
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Avatar + name + email card ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: AppColor.buttoncolor,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: provider.isUploadingPhoto
                                  ? null
                                  : () => _pickAndUploadPhoto(provider),
                              child: CircleAvatar(
                                radius: 48.r,
                                backgroundColor: Colors.white,
                                backgroundImage: profile.avatarUrl != null
                                    ? NetworkImage(profile.avatarUrl!)
                                    : null,
                                child: profile.avatarUrl == null
                                    ? Text(
                                  (profile.name?.isNotEmpty == true
                                      ? profile.name![0]
                                      : "S")
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 30.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColor.Buttontextcolor,
                                  ),
                                )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: provider.isUploadingPhoto
                                    ? null
                                    : () => _pickAndUploadPhoto(provider),
                                child: Container(
                                  width: 26.w,
                                  height: 26.w,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFBFBFBA),
                                    shape: BoxShape.circle,
                                  ),
                                  child: provider.isUploadingPhoto
                                      ? Padding(
                                    padding: EdgeInsets.all(5.w),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : Icon(Icons.edit, size: 13.sp, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (provider.photoUploadError != null) ...[
                          SizedBox(height: 8.h),
                          Text(
                            provider.photoUploadError!,
                            style: TextStyle(color: Colors.red, fontSize: 11.sp),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => _pickAndUploadPhoto(provider),
                            child: const Text("Retry upload"),
                          ),
                        ],

                        SizedBox(height: 14.h),

                        // ── Name + edit pencil ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                profile.name?.isNotEmpty == true
                                    ? profile.name!
                                    : "Add your name",
                                style: TextStyle(
                                  fontSize: 25.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.Buttontextcolor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            GestureDetector(
                              onTap: () => _openEditProfileDialog(provider),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 18.sp,
                                color: AppColor.Buttontextcolor,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 4.h),

                        Text(
                          profile.email,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColor.Buttontextcolor,
                          ),
                        ),

                        if (profile.phone != null && profile.phone!.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            profile.phone!,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColor.Buttontextcolor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── Selected course/exam card ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppColor.buttoncolor,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Your course",
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColor.Buttontextcolor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          profile.selectedCourse != null
                              ? (profile.selectedCourseType != null
                              ? "Currently: ${profile.selectedCourse!.title}"
                              " — ${profile.selectedCourseType!.title}"
                              : "Currently: ${profile.selectedCourse!.title}")
                              : "No exam selected yet",
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColor.Buttontextcolor,
                          ),
                        ),


                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── Menu items ──
                  Container(
                    decoration: BoxDecoration(
                      color: AppColor.buttoncolor,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuItem(
                          label: "Bookmarks",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                          ),
                        ),
                        _menuDivider(),
                        _ProfileMenuItem(label: "Learn more", onTap: () {}),
                        _menuDivider(),
                        _ProfileMenuItem(label: "FAQ", onTap: () {}),
                        _menuDivider(),
                        _ProfileMenuItem(label: "Contact us", onTap: () {}),
                        _menuDivider(),
                        _ProfileMenuItem(label: "Settings", onTap: () {}),
                        _menuDivider(),
                        _ProfileMenuItem(label: "Terms & Conditions", onTap: () {}),
                        _menuDivider(),
                        _ProfileMenuItem(label: "Share this app", onTap: () {}),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── Logout button ──
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: auth.isLoggingOut ? null : () => _handleLogout(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.buttoncolor,
                            foregroundColor: Colors.grey.shade600,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28.r),
                            ),
                          ),
                          child: auth.isLoggingOut
                              ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                            ),
                          )
                              : Text(
                            "Log out",
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColor.Buttontextcolor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _menuDivider() => Divider(
    height: 1,
    thickness: 1,
    color: Colors.white.withOpacity(0.6),
    indent: 16,
    endIndent: 16,
  );
}

class _ProfileMenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ProfileMenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: AppColor.Buttontextcolor,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20.sp, color: AppColor.Buttontextcolor),
          ],
        ),
      ),
    );
  }
}


