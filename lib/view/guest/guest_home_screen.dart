// lib/view/guest/guest_home_screen.dart
//
// What the app opens on before anyone signs in.
//
// The login screen used to be the front door, which asked a stranger to hand
// over an account before they had seen anything. This shows what is inside —
// the exams, what each one covers — and keeps signing in to the moment it is
// needed.
//
// It can only show the catalogue. Chapters, lessons and questions all sit
// behind /users/me/ and answer 401 without a session, so every tap here ends
// at the same place: sign in to open it.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theam /app_color.dart';
import '../../models/public_course_model.dart';
import '../../services/public_catalog_service.dart';
import '../../widget/access_chip.dart';
import '../../widget/app_loading.dart';
import '../../widget/app_logo.dart';
import '../../widget/app_refresh.dart';
import '../Authendication/login/login_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  /// Swapped in tests, which have no network.
  final PublicCatalogService? service;

  const GuestHomeScreen({super.key, this.service});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  late final PublicCatalogService _service =
      widget.service ?? PublicCatalogService();

  List<PublicCourse> _courses = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final courses = await _service.fetchCourses();
      if (!mounted) return;
      setState(() {
        _courses = courses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the courses. Pull down to try again.';
        _loading = false;
      });
    }
  }

  void _signIn() {
    // Pushed, not replaced: the gate swaps the whole tree the moment the
    // session lands, and a visitor who changes their mind can come back.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: _loading
                ? const AppLoading()
                : AppRefresh(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
                      children: [
                        Text(
                          _error ?? 'What you can study here',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: _error == null
                                ? const Color(0xFF1F2418)
                                : Colors.red.shade700,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        for (final course in _courses) ...[
                          _CourseCard(course: course, onTap: _signIn),
                          SizedBox(height: 12.h),
                        ],
                        if (_courses.isEmpty && _error == null)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.h),
                            child: Text(
                              'No courses published yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13.sp, color: Colors.grey.shade600),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          _SignInBar(onSignIn: _signIn),
        ],
      ),
    );
  }
}

/// The badge and the one line that says what this is.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          22.w, MediaQuery.of(context).padding.top + 22.h, 22.w, 26.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E8052), AppColor.buttoncolor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      child: Row(
        children: [
          AppLogo(size: 52.w),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Dr. SKM's Academy",
                  style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Gulf licensing exam preparation',
                  style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One course, with the exams inside it.
class _CourseCard extends StatelessWidget {
  final PublicCourse course;
  final VoidCallback onTap;

  const _CourseCard({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 15.h, 16.w, 15.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3D4A2C).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    course.title,
                    style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: Colors.black87),
                  ),
                ),
                SizedBox(width: 8.w),
                AccessChip(accessType: course.accessType),
              ],
            ),
            if (course.description != null) ...[
              SizedBox(height: 5.h),
              Text(
                course.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
              ),
            ],
            if (course.types.isNotEmpty) ...[
              SizedBox(height: 11.h),
              // The exams themselves — what a student is actually choosing
              // between, and the reason a catalogue of four courses is worth
              // showing at all.
              Wrap(
                spacing: 7.w,
                runSpacing: 7.h,
                children: [
                  for (final type in course.types) _ExamPill(title: type.title),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamPill extends StatelessWidget {
  final String title;

  const _ExamPill({required this.title});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: AppColor.buttoncolor.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3D4A2C)),
        ),
      );
}

/// The way in, always on screen.
class _SignInBar extends StatelessWidget {
  final VoidCallback onSignIn;

  const _SignInBar({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20.w, 14.h, 20.w, MediaQuery.of(context).padding.bottom + 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign in to start learning',
            style: TextStyle(
                fontSize: 12.5.sp,
                height: 1.4,
                color: Colors.grey.shade700),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: onSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.buttoncolor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r)),
              ),
              child: Text('Sign in',
                  style:
                      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
