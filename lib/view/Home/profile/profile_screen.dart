

import 'dart:io';
import 'package:flutter/material.dart';

import '../../../widget/app_refresh.dart';

import '../../../core/constant/local_storage.dart';
import '../../subjectSelection/select_exam_screen.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/app_snackbar.dart';
import 'info_screens.dart';
import 'privacy_policy_screen.dart';
import 'terms_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constant/app_size.dart';
import '../../../core/theam /app_color.dart';
import '../../../repository/profile_provider.dart';
import '../../../repository/refresh_api_provider.dart';
import '../../../widget/app_loading.dart';
import '../Qbank/bookmarks_screen.dart';
import '../../../core/utils/refresh_on_visible.dart';


const Color _kDanger = Color(0xFFD65745);

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
      showAppSnackBar(context, 'Profile photo updated');
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
              // The app's own background rather than the theme's white, so
              // the dialog reads as part of this app instead of a system
              // sheet dropped on top of it.
              backgroundColor: AppColor.Screenbackground,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                "Edit profile",
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17.sp,
                    color: AppColor.Textcolor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.errorMessage != null) ...[
                    // A tinted panel, not bare red text: on the cream
                    // background a line of red on nothing reads as a stray
                    // label rather than as the reason the save failed.
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD65745).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                            color: const Color(0xFFD65745).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 15.sp, color: const Color(0xFFB03A2B)),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              provider.errorMessage!,
                              style: TextStyle(
                                  color: const Color(0xFFB03A2B),
                                  fontSize: 12.sp,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),
                  ],
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: "Display name",
                      filled: true,
                      // White on cream, so the field reads as a field.
                      fillColor: Colors.white,
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
                      fillColor: Colors.white,
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
                  child: Text("Cancel",
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
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
                    backgroundColor: AppColor.buttoncolor,
                    foregroundColor: AppColor.Buttontextcolor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22.r)),
                    padding: EdgeInsets.symmetric(horizontal: 22.w),
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

  /// Opens the course picker over the profile.
  ///
  /// Pushed, not swapped: the student may back out without choosing, and the
  /// course they already have must survive that. The picker only writes on a
  /// successful save.
  Future<void> _changeCourse(BuildContext context) async {
    final tokens = await Future.wait([
      LocalStorage.getAccessToken(),
      LocalStorage.getRefreshToken(),
      LocalStorage.getDeviceId(),
    ]);

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamSelectionScreen(
          accessToken: tokens[0] ?? '',
          refreshToken: tokens[1] ?? '',
          deviceId: tokens[2] ?? '',
        ),
      ),
    );

    if (!context.mounted) return;

    // Changing course changes everything downstream — the lesson tree, the
    // tests, the daily quiz. Refetch both rather than leave the old course's
    // content on screen under a new course's name.
    await Future.wait([
      context.read<ProfileProvider>().loadProfile(),
      context.read<SelectionContentProvider>().loadContent(),
    ]);
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // The app's own background, not the theme's white. Material 3 also
        // paints a purple surface tint over that white, which is what made
        // this read as a system dialog dropped on top of the app.
        backgroundColor: AppColor.Screenbackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        icon: Icon(Icons.logout_rounded, size: 30.sp, color: _kDanger),
        title: Text("Log out?",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColor.Textcolor)),
        content: Text(
          "You'll need to sign in again to reach your course.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13.sp, height: 1.45, color: Colors.grey.shade700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kDanger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text("Log out",
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text("Stay signed in",
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ),
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

    // No navigation of our own. signOut() flips the status and AuthGate swaps
    // its root to the login screen.
    //
    // pushAndRemoveUntil removed AuthGate from the tree entirely — and
    // AuthGate is what listens for the session dying, so after one log-out
    // and sign-in the multi-device sign-out stopped working. Popping back to
    // the root is enough, and only when this screen was pushed.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      body: SafeArea(
        child: Consumer<ProfileProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const AppLoading();
            }

            if (provider.profile == null) {
              return Center(
                child: Text(provider.errorMessage ?? 'Failed to load profile'),
              );
            }

            _syncControllersFromProfile();
            final profile = provider.profile!;

            return AppRefresh(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                          SizedBox(height: 14.h),
                          Divider(
                              height: 1,
                              color: AppColor.Buttontextcolor.withValues(alpha: 0.25)),
                          SizedBox(height: 6.h),
                          InkWell(
                            onTap: () => _changeCourse(context),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz_rounded,
                                      size: 18.sp,
                                      color: AppColor.Buttontextcolor),
                                  SizedBox(width: 8.w),
                                  Text(
                                    profile.selectedCourse == null
                                        ? "Choose a course"
                                        : "Change course",
                                    style: TextStyle(
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColor.Buttontextcolor,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 20.sp,
                                      color: AppColor.Buttontextcolor),
                                ],
                              ),
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
                          _ProfileMenuItem(
                            label: "Learn more",
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const LearnMoreScreen())),
                          ),
                          _menuDivider(),
                          _ProfileMenuItem(
                            label: "FAQ",
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const FaqScreen())),
                          ),
                          _menuDivider(),
                          _ProfileMenuItem(
                            label: "Contact us",
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ContactUsScreen())),
                          ),
                          _menuDivider(),
                          _ProfileMenuItem(
                            label: "Settings",
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const SettingsScreen())),
                          ),
                          _menuDivider(),
                          _ProfileMenuItem(
                            label: "Terms & Conditions",
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const TermsScreen())),
                          ),
                          _menuDivider(),
                          _ProfileMenuItem(
                            label: "Privacy Policy",
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                          ),
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


