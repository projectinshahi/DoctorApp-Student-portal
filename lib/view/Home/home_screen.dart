import 'dart:async';
import 'package:dr_app/view/Home/profile/profile_screen.dart';
import 'package:flutter/material.dart';

import '../../widget/app_refresh.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/selection_content_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../repository/profile_provider.dart';
import '../../repository/notification_feed_provider.dart';
import '../../repository/plan_access_provider.dart';
import '../../repository/saved_provider.dart';
import '../../repository/settings_provider.dart';
import 'Qbank/bookmarks_screen.dart';
import 'Qbank/qbank_tab.dart';
import 'tests/tests_tab.dart';
import 'dashbord/ai_video_tab.dart';
import 'continue_learning_row.dart';
import 'notifications/notifications_screen.dart';
import 'recall/recall_lists_screen.dart';
import 'lessons/student_lesson_detail_screen.dart';
import '../../repository/daily_quiz_provider.dart';
import 'daily_quiz/daily_quiz_card.dart';
import '../../widget/home_loading.dart';
import '../../widget/learning_plan_dialog.dart';
import '../../widget/app_bottom_nav.dart';
import '../../core/utils/refresh_on_visible.dart';
import '../../core/utils/website.dart';
import '../../core/demo/demo_content.dart';
import '../../widget/sign_in_required.dart';


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
    // The preview carries a course, so Home, QBank and AI Videos have
    // something real to show. Grand Tests and Rapid Recall are the student's
    // own — papers sat, decks opened — and there is nothing to sample.
    if (DemoMode.active && (index == 2 || index == 4)) {
      showSignInRequired(context,
          what: index == 2 ? 'sit a grand test' : 'open your recall decks');
      return;
    }

    // Every tab opens. Access is decided per item inside them — a premium
    // lesson shows its paywall, a premium question is never in the set — so
    // a locked door at the tab would also shut out the free content behind
    // it, which is the part an unsubscribed student is here for.
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

      case 4: // Rapid Recall
        // Profile used to sit here. It moved to the header's drawer icon,
        // which already opened it — the nav slot was the second way in, and
        // Recall had none.
        _pushScreen(const RecallTopicsScreen());
        break;

      default:
      // Home (index 0) — nothing to navigate, already on this screen.
        break;
    }
  }

  @override
  void dispose() {
    // The timer outlives a frame, so it has to go or it fires setState on a
    // screen that is gone.
    _mcqCap?.cancel();
    super.dispose();
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
      // Read-only summary for the MCQ of the Day card. Starts nothing.
      context.read<HomeSummaryProvider>().load(),
      // Which tabs this student's plan covers, and the plan banner.
      context.read<PlanAccessProvider>().load(),
    ]);
  }

  /// The plan notice has been closed. Lives on the screen's state, so it
  /// stays closed while the app runs and is asked again on the next launch —
  /// which is where the plan itself is checked again.
  bool _gateDismissed = false;

  /// The MCQ card has reported in, or the cap ran out.
  bool _mcqReady = false;
  Timer? _mcqCap;

  bool get _readyToShow => _mcqReady;

  /// The card is the slowest thing on this page — /daily-quiz measured
  /// 1.5-5.3s — and it must never be able to hold the page hostage. Whatever
  /// has arrived by the cap is shown, and the card fills in behind it.
  static const _mcqWaitCap = Duration(milliseconds: 1200);

  void _startMcqCap() {
    _mcqCap ??= Timer(_mcqWaitCap, () {
      if (mounted && !_mcqReady) setState(() => _mcqReady = true);
    });
  }

  void _onMcqReady() {
    _mcqCap?.cancel();
    if (mounted && !_mcqReady) setState(() => _mcqReady = true);
  }

  @override
  Widget build(BuildContext context) {
    _startMcqCap();

    // The whole page, not a section of it. Half a home screen with a live
    // header over an empty body reads as broken rather than loading.
    // The nav bar stays put so the tabs are still reachable.
    // Only when there is genuinely nothing to draw. This used to be
    // `isLoading || isLoading`, so a profile fetch that was still in flight
    // blanked the whole page — including the course tree, which is restored
    // from disk and was already there. The greeting simply fills in when the
    // profile lands.
    final content = context.watch<SelectionContentProvider>();
    final profile = context.watch<ProfileProvider>();

    // Checked on every build — so on every app open, every refresh and the
    // moment a plan is bought — rather than once per session.
    final planInactive = learningPlanInactive(
      profile: profile.profile,
      content: content.content,
    );

    // Null outside the last days of the plan, so the countdown appears when
    // it is news rather than sitting there all year.
    final planDaysLeft = context.watch<PlanAccessProvider>().expiringInDays;

    // One skeleton for the page, not a loaded page with one card still
    // spinning — that mixed state is what read as broken. The MCQ card says
    // when its question has landed, and until then the whole page is the
    // skeleton.
    final loading =
        (content.isLoading && content.content == null) || !_readyToShow;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
      extendBody: true,
      backgroundColor: kBg,
      body: Column(
        children: [
          // Above the header rather than inside the scroll: a plan running
          // out is not something to find by scrolling.
          if (planDaysLeft != null) _ExpiryStrip(days: planDaysLeft),
          if (loading)
            const Expanded(child: HomeLoading())
          else
          Expanded(
            child: AppRefresh(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                                    if (DemoMode.active) {
                                      showSignInRequired(context,
                                          what: 'see your profile');
                                      return;
                                    }
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
                              _HeaderIconButton(
                                icon: Icons.notifications_none_rounded,
                                // What is waiting, unread. Watched, so a push arriving while
                                // home is open moves it.
                                badge: context.watch<NotificationFeedProvider>().unreadCount,
                                onTap: () =>
                                    DemoMode.active
                                        ? showSignInRequired(context,
                                            what: 'see your notifications')
                                        : NotificationsScreen.open(context),
                              ),
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
                                // A minimum, not a cap. The name wraps and the
                                // module count grows, and a fixed 165.h clipped
                                // them — 69px off the bottom at design size.
                                constraints: BoxConstraints(minHeight: 165.h),
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
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
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

                          // The notice has been closed and the plan is still
                          // not active. Said once more, quietly, where the
                          // student is already reading — closing the card is
                          // not the same as deciding against a plan, and
                          // without this there is nothing left on home that
                          // sells one.
                          // Says what this is. One line, not a nag: a
                          // visitor who cannot tell sample content from a
                          // real course has been misled, however good the
                          // screen looks.
                          if (DemoMode.active) ...[
                            const _PreviewBanner(),
                            SizedBox(height: 22.h),
                          ],

                          if (planInactive && _gateDismissed) ...[
                            const _NoPlanBanner(),
                            SizedBox(height: 22.h),
                          ],

                          // ── MCQ of the Day ──
                          //
                          // Replaces the old hardcoded "Continue MCQs" card.
                          // The summary comes from /users/me/home, which starts
                          // nothing; the card itself only fetches the question
                          // once an attempt exists or the student taps Start.
                          Consumer2<HomeSummaryProvider,
                              SelectionContentProvider>(
                            builder: (context, daily, content, _) {
                              final summary = daily.summary;
                              final courseId = content.content?.course?.id;

                              // Null when no course is picked yet — hide it.
                              if (summary == null || courseId == null) {
                                return const SizedBox.shrink();
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today MCQs",
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                                  ),
                                  SizedBox(height: 12.h),
                                  DailyQuizCard(
                                    // Keyed on the date so the card rebuilds
                                    // from scratch when the set rolls over at
                                    // midnight Gulf time.
                                    key: ValueKey(summary.date),
                                    summary: summary,
                                    courseId: courseId,
                                    onChanged: () => context
                                        .read<HomeSummaryProvider>()
                                        .load(),
                                    onReady: _onMcqReady,
                                  ),
                                ],
                              );
                            },
                          ),

                          SizedBox(height: 28.h),

                          // ── Continue Learning ──
                          //
                          // Two cards: the video they left, and the one after
                          // it. Replaces both the Continue Watching row and the
                          // lesson grid — a home screen is somewhere to resume
                          // from, and a full catalogue here buried the one
                          // lesson the student actually wanted.
                          Consumer2<HomeSummaryProvider,
                              SelectionContentProvider>(
                            builder: (context, home, content, _) {
                              final items = pickLearningItems(
                                inProgress: home.inProgressVideos,
                                content: content.content,
                              );
                              if (items.isEmpty) return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ContinueLearningRow(
                                    items: items,
                                    onOpen: (lesson) async {
                                      if (DemoMode.active) {
                                        await showSignInRequired(context,
                                            what: 'watch this lesson');
                                        return;
                                      }

                                      // Same answer as every other list: a
                                      // padlocked lesson says why here rather
                                      // than opening a screen with nothing in
                                      // it but a paywall.
                                      if (!lesson.isOpen) {
                                        await showPlanRequiredDialog(context,
                                            lessonTitle: lesson.title);
                                        return;
                                      }

                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudentLessonDetailScreen(
                                              lesson: lesson),
                                        ), 
                                      );
                                      // On return only — the player already
                                      // drops a finished video from the list.
                                      if (context.mounted) {
                                        context.read<HomeSummaryProvider>().load();
                                      }
                                    },
                                  ),
                                  SizedBox(height: 28.h),
                                ],
                              );
                            },
                          ),

                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Floating bottom nav bar ──
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _handleNavTap,
      ),
        ),
        // Nothing behind it is reachable while the plan is inactive: no
        // courses, no tabs, no bell.
        if (planInactive && !_gateDismissed)
          LearningPlanGate(onClose: () => setState(() => _gateDismissed = true)),
      ],
    );
  }
}

/// "You are looking at a sample" — on home, before anyone signs in.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showSignInRequired(context),
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 15.h, 14.w, 15.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6E8052), Color(0xFF87986B)],
          ),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 20.sp, color: Colors.white),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are viewing a sample',
                      style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  SizedBox(height: 3.h),
                  Text('Sign in to open your own course and track progress.',
                      style: TextStyle(
                          fontSize: 11.5.sp,
                          height: 1.4,
                          color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text('Sign in',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3D4A2C))),
            ),
          ],
        ),
      ),
    );
  }
}

/// The plan offer on home, once the full-screen notice has been closed.
///
/// A card the student scrolls past rather than a warning bar: they have
/// already closed one notice, and repeating it in the same words would be
/// nagging. This one is written as what they would get, not what they lack.
class _NoPlanBanner extends StatelessWidget {
  const _NoPlanBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openWebsite(context),
      child: Container(
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6E8052), Color(0xFF87986B)],
          ),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13.r),
              ),
              child: Icon(Icons.workspace_premium_rounded,
                  size: 21.sp, color: Colors.white),
            ),
            SizedBox(width: 13.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock the full course',
                    style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Every lesson, test and recall deck, on our website.',
                    style: TextStyle(
                        fontSize: 11.5.sp,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.88)),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text('Explore',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3D4A2C))),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's green, at the strength a background strip wants.
const Color _kStripTint = Color(0x1F87986B);


/// "Your plan ends in 6 days" — the countdown, for the last stretch of a
/// subscription.
///
/// Renewing happens on the website like every other purchase, so the whole
/// strip is the tap that opens it.
class _ExpiryStrip extends StatelessWidget {
  final int days;

  const _ExpiryStrip({required this.days});

  @override
  Widget build(BuildContext context) {
    // Amber for the last week, the app's own green before that: the same
    // sentence should not look the same on day ten as on day two.
    final urgent = days <= 7;
    final tint = urgent ? const Color(0x1FE8A33D) : _kStripTint;
    final ink = urgent ? const Color(0xFF8A5B18) : const Color(0xFF3D4A2C);

    return Material(
      color: tint,
      child: InkWell(
        onTap: () => openWebsite(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 9.h),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 15.sp, color: ink),
              SizedBox(width: 9.w),
              Expanded(
                child: Text(
                  // Phrased once, next to the counting itself.
                  planEndsLabel(days),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.sp, fontWeight: FontWeight.w600, color: ink),
                ),
              ),
              Text('Renew',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                      decorationColor: ink,
                      color: ink)),
              SizedBox(width: 2.w),
              Icon(Icons.chevron_right_rounded, size: 16.sp, color: ink),
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

  /// Null leaves the button inert. Nothing passes null today.
  final VoidCallback? onTap;

  /// How many are waiting. Zero draws nothing at all — a "0" on a bell is
  /// noise, not news.
  final int badge;

  const _HeaderIconButton({required this.icon, this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40.w,
        height: 40.w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, size: 20.sp, color: const Color(0xFF87986B)),
            ),
            if (badge > 0)
              Positioned(
                right: -2.w,
                top: -2.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  constraints: BoxConstraints(minWidth: 17.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB03A2B),
                    borderRadius: BorderRadius.circular(9.r),
                    border: Border.all(color: Colors.white, width: 1.4),
                  ),
                  child: Text(
                    // Past 99 the number stops being worth reading.
                    badge > 99 ? '99+' : '$badge',
                    style: TextStyle(
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

