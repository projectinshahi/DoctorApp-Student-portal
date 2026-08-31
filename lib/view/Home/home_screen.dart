import 'package:dr_app/view/Home/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/selection_content_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../repository/profile_provider.dart';
import '../../repository/saved_provider.dart';
import 'Qbank/bookmarks_screen.dart';
import 'Qbank/qbank_tab.dart';
import 'tests/tests_tab.dart';
import 'dashbord/ai_video_tab.dart';
import 'lessons/student_lesson_detail_screen.dart';
import '../../widget/app_shimmer.dart';
import '../../core/utils/refresh_on_visible.dart';

// If you still keep a separate "AI Videos list" screen, import it too.
// import 'ai_videos_screen.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> with RefreshOnVisible<Homescreen> {
  int _currentNavIndex = 0;

  static const Color kPrimary = Color(0xFF87986B);
  static const Color kBg = Color(0xFFEFF4E2);

  void _pushScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      if (mounted) setState(() => _currentNavIndex = 0);
    });
  }

  // ── Handles nav bar taps: some tabs just update the selected visual
  // state, others (like AI Videos) actually navigate to a real screen. ──
  void _handleNavTap(int index) {
    setState(() => _currentNavIndex = index);

    switch (index) {
      case 1: // QBank — now shows the selected-course details
        _pushScreen(const QbankTab());
        break;

      case 2:
        _pushScreen(const TestsTab());
        break;

      case 3: // AI Videos
        _pushScreen(const AiVideoTab());
        break;

      case 4:
        _pushScreen(const ProfileScreen());
        break;

      default:
      // Home (index 0) — nothing to navigate, already on this screen.
        break;
    }
  }

  // ── Also called when the user taps the "AI picks for you" video card,
  // so it opens the same detail screen with that specific lesson. ──
  void _openAiPickVideo() {
    final StudentLessonModel pickedLesson = StudentLessonModel(
      id: 102,
      title: "Inferior STEMI walkthrough",
      description: "Cardiology",
      type: "video",
      content: null,
      videoUrl: "https://your-cdn.com/videos/inferior_stemi.mp4",
      thumbnailUrl: "https://your-cdn.com/thumbs/inferior_stemi.jpg",
      noteUrl: null,
      noteFileType: null,
      displayOrder: 1,
      isFreePreview: true,
      accessType: "free",
      locked: false,
    );

    _pushScreen(StudentLessonDetailScreen(lesson: pickedLesson));
  }

  @override
  void initState() {
    super.initState();
  }

  /// Everything the home screen renders. Runs on first appearance and again
  /// each time a tab is closed and this screen comes back into view.
  @override
  Future<void> onRefresh() async {
    if (!mounted) return;
    await Future.wait([
      context.read<SelectionContentProvider>().loadContent(),
      // The header's name.
      context.read<ProfileProvider>().loadProfile(),
      // Bookmarks: the QBank badge and every bookmark icon read from here.
      context.read<SavedProvider>().loadAll(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // The whole page, not a section of it. Half a home screen with a live
    // header over a shimmering body reads as broken rather than loading.
    // The nav bar stays put so the tabs are still reachable.
    final loading = context.watch<SelectionContentProvider>().isLoading ||
        context.watch<ProfileProvider>().isLoading;

    return Scaffold(
      extendBody: true,
      backgroundColor: kBg,
      body: Column(
        children: [
          if (loading)
            const Expanded(child: _HomeShimmer())
          else
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 100.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─────────────────────────────────────────────
                  // Header
                  // ─────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    height: 250.h,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(35.r)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 32.w,
                              height: 40.h,
                              child: IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                  );
                                },
                                icon: Image.asset(
                                  'asset/icons/drawer_icon.png',
                                  width: 23.33.w,
                                  height: 16.67.h,
                                  fit: BoxFit.contain,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            SizedBox(width: 20.w),

                            // 👇 Name now comes from ProfileProvider instead of
                            // being hardcoded as "Dr. David Thomson".
                            Expanded(
                              child: Consumer<ProfileProvider>(
                                builder: (context, profileProvider, _) {
                                  final profile = profileProvider.profile;

                                  final displayName = profile?.name?.isNotEmpty == true
                                      ? profile!.name!
                                      : "Doctor";

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Heyyy",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white.withOpacity(0.85),
                                        ),
                                      ),
                                      if (profileProvider.isLoading && profile == null)
                                        SizedBox(
                                          height: 16.h,
                                          width: 90.w,
                                          child: LinearProgressIndicator(
                                            backgroundColor: Colors.white.withOpacity(0.2),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      else
                                        Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),

                            SizedBox(width: 10.w),
                            _HeaderIconButton(
                              icon: Icons.bookmark_border_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            _HeaderIconButton(icon: Icons.notifications_none_rounded),
                          ],
                        ),
                        SizedBox(height: 32.h),
                        Container(
                          width: double.infinity,
                          height: 50.h,
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20.sp),
                              SizedBox(width: 6.w),
                              Expanded(
                                child: Text(
                                  "Search MCQ IDs, Pearl IDs, topics ....",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),

                        // ── Welcome back card ──
                        Consumer<ProfileProvider>(
                          builder: (context, profileProvider, _) {
                            final profile = profileProvider.profile;
                            final firstName = profile?.name?.isNotEmpty == true
                                ? profile!.name!.split(' ').first
                                : "Doctor";

                            return Container(
                              width: double.infinity,
                              height: 165.h,
                              padding: EdgeInsets.all(18.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7E7E7),
                                borderRadius: BorderRadius.circular(24.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Welcome back $firstName",
                                                    style: TextStyle(
                                                      fontSize: 18.sp,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  SizedBox(height: 8.h),
                                                  Text(
                                                    "Consistency today, success\ntomorrow, Keep going!!",
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      color: Colors.grey.shade600,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Divider(color: Colors.white, thickness: 1),
                                        // Chapters at 100%, from the server's
                                        // own per-chapter progress.
                                        Text(
                                          "${context.watch<SelectionContentProvider>().content?.completedModules ?? 0} Modules completed",
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    flex: 3,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: Image.asset('asset/icons/banner_icon.png'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        SizedBox(height: 26.h),

                        // ── Continue MCQs ──
                        Text(
                          "Continue MCQs",
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        SizedBox(height: 12.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(18.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "A 6-month-old presented with a genetic disorder "
                                    "attributed to multifactorial inheritance. This type "
                                    "of inheritance is most likely to play a significant "
                                    "role in which of the following disorder?",
                                style: TextStyle(
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              _McqOption(label: "A", text: "Achondroplasia"),
                              SizedBox(height: 10.h),
                              _McqOption(label: "B", text: "Lysosomal storage disease"),
                              SizedBox(height: 10.h),
                              _McqOption(label: "c", text: "Lysosomal storage disease"),
                              SizedBox(height: 10.h),
                              _McqOption(label: "B", text: "Lysosomal storage disease"),
                            ],
                          ),
                        ),

                        SizedBox(height: 28.h),

                        Consumer<SelectionContentProvider>(
                          builder: (context, provider, _) {
                            if (provider.isLoading) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: ScreenShimmer(layout: ShimmerLayout.grid),
                              );
                            }

                            // Videos and notes only — quiz lessons belong in QBank.
                            final lessons = <StudentLessonModel>[];
                            for (final chapter in provider.content?.chapters ?? const <StudentChapterModel>[]) {
                              lessons.addAll(chapter.lessons.where((l) => l.isWatchable));
                            }

                            if (provider.errorMessage != null && lessons.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  provider.errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            if (lessons.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Your selected course lessons",
                                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                                SizedBox(height: 12.h),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: lessons.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.82,
                                  ),
                                  itemBuilder: (context, index) {
                                    final lesson = lessons[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StudentLessonDetailScreen(lesson: lesson),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16.r),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: EdgeInsets.all(10.w),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // The tile's height comes from the grid's childAspectRatio,
                                            // which doesn't track ScreenUtil's .h scaling — a fixed 90.h
                                            // thumbnail overflowed the column on wide/short viewports.
                                            // Letting the thumbnail take whatever is left can't overflow.
                                            Expanded(
                                              child: lesson.thumbnailUrl != null
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(12.r),
                                                      child: Image.network(
                                                        lesson.thumbnailUrl!,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : Container(
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF87986B),
                                                        borderRadius: BorderRadius.circular(12.r),
                                                      ),
                                                      child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white),
                                                    ),
                                            ),
                                            SizedBox(height: 10.h),
                                            Text(
                                              lesson.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
                                            ),
                                            SizedBox(height: 6.h),
                                            Row(
                                              children: [
                                                if (lesson.hasVideo)
                                                  const Icon(Icons.videocam_outlined, size: 14, color: Colors.green),
                                                if (lesson.hasNote)
                                                  const Icon(Icons.description_outlined, size: 14, color: Colors.orange),
                                                const Spacer(),
                                                if (lesson.locked)
                                                  const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 28.h),
                              ],
                            );
                          },
                        ),

                        // ── Continue Learning ──
                        Text(
                          "Continue Learning",
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(child: _LearningCard(title: "DHA Case : Chest pain inferior STEMI")),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _LearningCard(
                                title: "Cardiology – Ischemic Heart Disease",
                                icon: Icons.favorite_rounded,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 28.h),

                        // ── AI picks for you ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "AI picks for you",
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _openAiPickVideo, // 👈 opens StudentLessonDetailScreen
                                child: _AiPickCard(
                                  icon: Icons.play_arrow_rounded,
                                  tagText: "Recommended video",
                                  title: "Inferior STEMI walkthrough",
                                  subtitle: "Cardiology",
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _AiPickCard(
                                icon: Icons.bloodtype_rounded,
                                tagText: "Weak area - practice",
                                title: "Hematology rapid fire MCQs",
                                subtitle: "Hematology",
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Floating bottom nav bar ──
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Container(
          height: 75.h,
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(30.r),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: "Home",
                isSelected: _currentNavIndex == 0,
                onTap: () => _handleNavTap(0),
              ),
              _NavItem(
                icon: Icons.help_outline_rounded,
                label: "QBank",
                isSelected: _currentNavIndex == 1,
                onTap: () => _handleNavTap(1),
              ),
              _NavItem(
                icon: Icons.description_outlined,
                label: "Tests",
                isSelected: _currentNavIndex == 2,
                onTap: () => _handleNavTap(2),
              ),
              _NavItem(
                icon: Icons.play_circle_outline_rounded,
                label: "AI Videos",
                isSelected: _currentNavIndex == 3,
                onTap: () => _handleNavTap(3),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: "Profile",
                isSelected: _currentNavIndex == 4,
                onTap: () => _handleNavTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header icon button (bookmark / bell) ──
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;

  /// Null leaves the button inert — which is what the notifications one still
  /// is, since there is no notifications screen to open yet.
  final VoidCallback? onTap;

  const _HeaderIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 20.sp, color: const Color(0xFF87986B)),
      ),
    );
  }
}

// ── MCQ answer option row ──
class _McqOption extends StatelessWidget {
  final String label;
  final String text;
  const _McqOption({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F1),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13.r,
            backgroundColor: Colors.white,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continue Learning card ──
class _LearningCard extends StatelessWidget {
  final String title;
  final IconData icon;
  const _LearningCard({required this.title, this.icon = Icons.play_arrow_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF87986B),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 16.sp, color: const Color(0xFF87986B)),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ── AI picks card ──
class _AiPickCard extends StatelessWidget {
  final IconData icon;
  final String tagText;
  final String title;
  final String subtitle;

  const _AiPickCard({
    required this.icon,
    required this.tagText,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF87986B),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 15.sp, color: const Color(0xFF87986B)),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 10.sp, color: Colors.white),
                    SizedBox(width: 2.w),
                    Text(
                      "AI",
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            tagText,
            style: TextStyle(fontSize: 10.5.sp, color: Colors.white.withOpacity(0.75)),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11.sp, color: Colors.white.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// ── Bottom nav item ──
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 25.sp, color: isSelected ? Colors.white : Colors.white.withOpacity(0.55)),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton of the home screen, block for block.
///
/// A generic list shimmer settles into a visibly different page, which reads
/// as the layout jumping rather than as content arriving. So this mirrors the
/// real thing: the green header with its rounded bottom and search bar, the
/// welcome card, the MCQ card, then the lesson grid — at the same sizes the
/// live widgets use.
class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  static const _kPrimary = Color(0xFF87986B);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Not scrollable while loading: the skeleton is the whole page.
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header. Keeps its real colour so the page does not flash from
          // grey to green when the data lands. ──
          Container(
            width: double.infinity,
            height: 250.h,
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(35.r)),
            ),
            child: SafeArea(
              bottom: false,
              child: AppShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ShimmerBox(width: 44.w, height: 44.w, radius: 22.r),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShimmerBox(width: 70.w, height: 12.h, radius: 6.r),
                            SizedBox(height: 8.h),
                            ShimmerBox(width: 130.w, height: 14.h, radius: 6.r),
                          ],
                        ),
                        const Spacer(),
                        ShimmerBox(width: 40.w, height: 40.w, radius: 20.r),
                        SizedBox(width: 10.w),
                        ShimmerBox(width: 40.w, height: 40.w, radius: 20.r),
                      ],
                    ),
                    SizedBox(height: 28.h),
                    ShimmerBox(width: double.infinity, height: 48.h, radius: 24.r),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 44.h, 20.w, 0),
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome card — same 165.h the live one uses.
                  ShimmerBox(width: double.infinity, height: 165.h, radius: 18.r),
                  SizedBox(height: 26.h),

                  // "Continue MCQs" heading, then its card.
                  ShimmerBox(width: 130.w, height: 15.h, radius: 6.r),
                  SizedBox(height: 12.h),
                  ShimmerBox(width: double.infinity, height: 190.h, radius: 18.r),
                  SizedBox(height: 28.h),

                  // Lesson grid heading and two rows of cards.
                  ShimmerBox(width: 160.w, height: 15.h, radius: 6.r),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(child: ShimmerBox(width: double.infinity, height: 120.h, radius: 14.r)),
                      SizedBox(width: 12.w),
                      Expanded(child: ShimmerBox(width: double.infinity, height: 120.h, radius: 14.r)),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(child: ShimmerBox(width: double.infinity, height: 120.h, radius: 14.r)),
                      SizedBox(width: 12.w),
                      Expanded(child: ShimmerBox(width: double.infinity, height: 120.h, radius: 14.r)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
