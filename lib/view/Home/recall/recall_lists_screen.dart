// lib/view/Home/recall/recall_lists_screen.dart
//
// Rapid Recall, top level: topic chips across the top, the selected topic's
// lessons underneath.
//
// One screen rather than a topics screen and a lessons screen: the chips put
// every topic one tap apart, where a separate screen made switching topic a
// back-and-forward each time.
//
// Fetches nothing of its own beyond the one list — the provider groups it on
// the device, so changing topic never waits on the network.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widget/app_refresh.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/refresh_on_visible.dart';
import '../../../models/rapid_recall_model.dart';
import '../../../repository/plan_access_provider.dart';
import '../../../repository/rapid_recall_provider.dart';
import '../../../widget/feature_locked_dialog.dart';
import '../../../widget/app_bottom_nav.dart';
import '../../../widget/app_loading.dart';
import '../Qbank/qbank_subjects_screen.dart' show QbankRowTile;
import '../Qbank/qbank_tab.dart';
import '../dashbord/ai_video_tab.dart';
import '../tests/tests_tab.dart';
import 'recall_decks_screen.dart';

const Color kRecallPrimary = Color(0xFF87986B);
const Color kRecallBg = Color(0xFFEFF4E2);

/// Clears the floating nav bar at the foot of a scrolling Recall screen, so
/// the last row is never left sitting under it.
double get kRecallNavClearance => 110.h;

class RecallTopicsScreen extends StatefulWidget {
  const RecallTopicsScreen({super.key});

  @override
  State<RecallTopicsScreen> createState() => _RecallTopicsScreenState();
}

class _RecallTopicsScreenState extends State<RecallTopicsScreen>
    with RefreshOnVisible<RecallTopicsScreen> {
  final ScrollController _chips = ScrollController();

  /// The chosen topic's chapter id. Separate from [_picked] because null is a
  /// real id here — it is the "General" topic.
  int? _selected;
  bool _picked = false;

  /// The one fetch the feature makes. Silent after the first: the list stays
  /// on screen while it refreshes underneath.
  @override
  Future<void> onRefresh() => context.read<RapidRecallProvider>().load();

  @override
  void dispose() {
    _chips.dispose();
    super.dispose();
  }

  /// The chosen topic, or the first one. Looked up by id on every build, so a
  /// topic that disappears on refresh falls back instead of pointing at
  /// nothing.
  RecallGroup _current(List<RecallGroup> topics) {
    if (_picked) {
      for (final topic in topics) {
        if (topic.id == _selected) return topic;
      }
    }
    return topics.first;
  }

  /// The » button: along by a chip or two, and back to the start from the
  /// end.
  void _nudgeChips() {
    if (!_chips.hasClients) return;
    final position = _chips.position;
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    _chips.animateTo(
      atEnd
          ? 0
          : math.min(position.pixels + 180.w, position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recall = context.watch<RapidRecallProvider>();
    final topics = recall.topics;

    // Only a cold load spins. Once there are decks the refresh happens under
    // what is already on screen.
    final Widget body;
    if (recall.isLoading && recall.decks.isEmpty) {
      body = const AppLoading();
    } else if (recall.errorMessage != null && recall.decks.isEmpty) {
      body = AppRefresh.fill(
          onRefresh: onRefresh,
          child: RecallMessage(text: recall.errorMessage!));
    } else if (recall.reason != null && recall.decks.isEmpty) {
      // The server's own sentence — "No course selected yet." — which is a
      // different answer from an empty shelf.
      body = AppRefresh.fill(
          onRefresh: onRefresh, child: RecallMessage(text: recall.reason!));
    } else if (topics.isEmpty) {
      body = AppRefresh.fill(
          onRefresh: onRefresh,
          child: const RecallMessage(text: 'No recall cards here yet.'));
    } else {
      final topic = _current(topics);
      final lessons = recall.lessonsIn(topic.id);

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 6.h, 8.w, 0),
            child: Row(
              children: [
                Text(
                  'Topics',
                  style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87),
                ),
                const Spacer(),
                if (topics.length > 1)
                  IconButton(
                    onPressed: _nudgeChips,
                    tooltip: 'More topics',
                    icon: Icon(Icons.keyboard_double_arrow_right_rounded,
                        size: 22.sp, color: Colors.grey.shade700),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 46.h,
            child: ListView.separated(
              controller: _chips,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              itemCount: topics.length,
              separatorBuilder: (_, _) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final chip = topics[index];
                return _TopicChip(
                  label: chip.title,
                  selected: chip.id == topic.id,
                  onTap: () => setState(() {
                    _picked = true;
                    _selected = chip.id;
                  }),
                );
              },
            ),
          ),
          SizedBox(height: 18.h),
          Expanded(
            child: AppRefresh(
              onRefresh: onRefresh,
              child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                // Keyed by topic, so switching chips starts the new list at the
                // top instead of wherever the last one was scrolled to.
                key: PageStorageKey('recall-lessons-${topic.id}'),
                padding:
                    EdgeInsets.fromLTRB(20.w, 0, 20.w, kRecallNavClearance),
                itemCount: lessons.length,
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  // The same row the QBank lists use — the same kind of list,
                  // and two separately styled copies would drift.
                  return QbankRowTile(
                    icon: recallIconFor(lesson.title),
                    title: lesson.title,
                    subtitle: lesson.summary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecallDecksScreen(
                          chapterId: topic.id,
                          lessonId: lesson.id,
                          title: lesson.title,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: kRecallBg,
      // The bar floats over the list, as it does on home.
      extendBody: true,
      appBar: recallAppBar(context, title: 'Rapid Recall'),
      body: body,
      // Already on Recall: tapping it again has nowhere to go.
      bottomNavigationBar: AppBottomNav(
        currentIndex: 4,
        locked: context.watch<PlanAccessProvider>().lockedTabs,
        onTap: (index) {
          if (index != 4) openTabFromRecall(context, index);
        },
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kRecallPrimary : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: selected ? kRecallPrimary : Colors.grey.shade400,
            width: 1.1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// The app bar every Recall screen shares: back, a title, an optional line
/// under it, and optional buttons on the right.
PreferredSizeWidget recallAppBar(
  BuildContext context, {
  required String title,
  String? subtitle,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: kRecallBg,
    surfaceTintColor: kRecallBg,
    elevation: 0,
    foregroundColor: Colors.black,
    titleSpacing: 0,
    leading: IconButton(
      onPressed: () => Navigator.maybePop(context),
      icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
    ),
    actions: actions,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600),
          ),
      ],
    ),
  );
}

/// A tab tapped from inside Recall. Back to home first, then the tab — the
/// same stack home builds when the tab is tapped there, so back from it
/// lands on home rather than on a Recall screen left underneath.
void openTabFromRecall(BuildContext context, int index) {
  // The same tabs are locked here as on home — otherwise the bar in Recall
  // is a way around the one on home.
  const names = {1: 'QBank', 2: 'Grand Tests', 3: 'AI Videos'};
  final access = context.read<PlanAccessProvider>();
  if (access.lockedTabs.contains(index)) {
    showFeatureLockedDialog(context,
        feature: names[index] ?? 'This section',
        planTitle: access.subscription?.planTitle);
    return;
  }

  final navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);

  final Widget? tab = switch (index) {
    1 => const QbankTab(),
    2 => const TestsTab(),
    3 => const AiVideoTab(),
    4 => const RecallTopicsScreen(),
    _ => null, // Home: popping back to it was the whole job.
  };
  if (tab != null) {
    navigator.push(MaterialPageRoute(builder: (_) => tab));
  }
}

class RecallMessage extends StatelessWidget {
  final String text;

  const RecallMessage({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
        ),
      );
}

/// An icon for a lesson, picked from words in its title.
///
/// ponytail: keyword match on the title, so a renamed lesson can lose its
/// icon; if admins need control, the backend sends an icon key per lesson.
IconData recallIconFor(String title) {
  final name = title.toLowerCase();
  for (final entry in _lessonIcons.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return Icons.menu_book_rounded;
}

/// Checked in order, so the more specific words come first — "neonat" before
/// anything a paediatrics title might also contain.
const Map<String, IconData> _lessonIcons = {
  'cardio': Icons.favorite_border_rounded,
  'heart': Icons.favorite_border_rounded,
  'pulmo': Icons.air_rounded,
  'respir': Icons.air_rounded,
  'lung': Icons.air_rounded,
  'gastro': Icons.restaurant_outlined,
  'hepat': Icons.restaurant_outlined,
  'nephro': Icons.water_drop_outlined,
  'renal': Icons.water_drop_outlined,
  'kidney': Icons.water_drop_outlined,
  'neuro': Icons.psychology_outlined,
  'psych': Icons.self_improvement_rounded,
  'endocr': Icons.science_outlined,
  'diabet': Icons.science_outlined,
  'rheum': Icons.accessibility_new_rounded,
  'infect': Icons.coronavirus_outlined,
  'hemat': Icons.bloodtype_outlined,
  'haemat': Icons.bloodtype_outlined,
  'blood': Icons.bloodtype_outlined,
  'onco': Icons.biotech_outlined,
  'cancer': Icons.biotech_outlined,
  'emergen': Icons.emergency_outlined,
  'critical': Icons.emergency_outlined,
  'neonat': Icons.child_friendly_outlined,
  'pediat': Icons.child_care_rounded,
  'paediat': Icons.child_care_rounded,
  'obstet': Icons.pregnant_woman_rounded,
  'gyn': Icons.pregnant_woman_rounded,
  'surg': Icons.content_cut_rounded,
  'ortho': Icons.accessibility_rounded,
  'derma': Icons.face_outlined,
  'ophthal': Icons.visibility_outlined,
  'pharma': Icons.medication_outlined,
  'medicine': Icons.medical_services_outlined,
};
