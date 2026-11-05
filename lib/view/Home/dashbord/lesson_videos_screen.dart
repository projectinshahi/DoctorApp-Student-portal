// lib/view/Home/dashbord/lesson_videos_screen.dart
//
// One subject's videos: "Cardiology · 8 Videos".
//
// A lesson is a container of videos now, so this is the level between the
// subject list and the player — the screen a student lands on after picking
// a subject, and the one the design shows as a list of thumbnails.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/demo/demo_content.dart';
import '../../../models/selection_content_model.dart';
import '../../../repository/saved_provider.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/access_chip.dart';
import '../../../widget/app_refresh.dart';
import '../../../widget/sign_in_required.dart';
import '../../../widget/learning_plan_dialog.dart';
import '../lessons/student_lesson_detail_screen.dart';

const Color _kBg = Color(0xFFEFF4E2);
const Color _kPrimary = Color(0xFF87986B);

class LessonVideosScreen extends StatefulWidget {
  final StudentLessonModel lesson;

  const LessonVideosScreen({super.key, required this.lesson});

  @override
  State<LessonVideosScreen> createState() => _LessonVideosScreenState();
}

class _LessonVideosScreenState extends State<LessonVideosScreen> {
  String _query = '';

  /// The design shows four, then offers the rest. A subject with eight
  /// videos should not open as a wall of them.
  static const int _preview = 4;
  bool _showAll = false;

  /// The live copy of this lesson, so a part unlocked by a purchase appears
  /// without coming back to this screen twice.
  StudentLessonModel get _lesson {
    final tree = context.watch<SelectionContentProvider>().content;
    for (final lesson in tree?.allLessons ?? const <StudentLessonModel>[]) {
      if (lesson.id == widget.lesson.id) return lesson;
    }
    return widget.lesson;
  }

  List<LessonVideo> _visible(StudentLessonModel lesson) {
    final parts = lesson.videoParts;
    if (_query.isEmpty) return parts;
    return parts
        .where((v) => v.title.toLowerCase().contains(_query))
        .toList();
  }

  List<LessonVideo> _shown(List<LessonVideo> parts) =>
      _showAll || _query.isNotEmpty || parts.length <= _preview
          ? parts
          : parts.take(_preview).toList();

  Future<void> _open(StudentLessonModel lesson, LessonVideo part) async {
    if (!part.isOpen) {
      // No url to play: the only honest answer is what it costs. The same
      // notice as a locked quiz, a locked paper and a locked deck — one
      // sentence for the whole app, not one per screen.
      if (DemoMode.active) {
        await showSignInRequired(context, what: 'watch the premium videos');
      } else {
        await showPlanRequiredDialog(context, lessonTitle: part.title);
      }
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentLessonDetailScreen(
          lesson: lesson,
          initialPartId: part.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final parts = _visible(lesson);

    // The tree already says which videos this student saved, so the rows are
    // drawn with their bookmarks filled rather than empty until /saved
    // answers. Seeding is a no-op when it has nothing new.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SavedProvider>().seedVideos(
            lesson.videoParts.where((v) => v.isSaved).map((v) => v.id),
          );
    });

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18.sp, color: Colors.black87),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            Text(
              '${lesson.videoParts.length} '
              '${lesson.videoParts.length == 1 ? 'Video' : 'Videos'}',
              style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: AppRefresh(
        onRefresh: () =>
            context.read<SelectionContentProvider>().loadContent(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          children: [
            _SearchField(
              hint: 'Search videos',
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            SizedBox(height: 16.h),
            if (parts.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 40.h),
                child: Text(
                  _query.isEmpty
                      ? 'No videos in this subject yet.'
                      : 'No videos match "$_query".',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                ),
              )
            else ...[
              for (final part in _shown(parts)) ...[
                _VideoRow(
                  part: part,
                  // Per video: bookmarking the second row used to fill every
                  // row, because it saved the lesson they all sit in.
                  saved: context.watch<SavedProvider>().isVideoSaved(part.id),
                  onBookmark: () =>
                      context.read<SavedProvider>().toggleVideo(part.id),
                  onTap: () => _open(lesson, part),
                ),
                SizedBox(height: 12.h),
              ],
              // Hidden while searching: a result list is already the short
              // answer to a question.
              if (!_showAll && _query.isEmpty && parts.length > _preview)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rounded search field both video screens use.
class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 19.sp, color: Colors.grey.shade500),
          SizedBox(width: 9.w),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(fontSize: 13.sp, color: Colors.black87),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle:
                    TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One video: still, length, title, and the bookmark.
class _VideoRow extends StatelessWidget {
  final LessonVideo part;
  final bool saved;
  final VoidCallback onBookmark;
  final VoidCallback onTap;

  const _VideoRow({
    required this.part,
    required this.saved,
    required this.onBookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            _Thumbnail(part: part),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5.sp,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: part.isOpen
                            ? Colors.black87
                            : Colors.grey.shade600),
                  ),
                  if (part.description != null) ...[
                    SizedBox(height: 3.h),
                    Text(
                      part.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5.sp, color: Colors.grey.shade600),
                    ),
                  ],
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      if (part.viewsLabel != null)
                        Text(part.viewsLabel!,
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.grey.shade600)),
                      // Both tiers are labelled. A padlock says this
                      // student cannot open it; only the chip says what it
                      // would take, and a row with neither reads as broken.
                      if (part.viewsLabel != null) SizedBox(width: 8.w),
                      AccessChip(accessType: part.accessType),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            GestureDetector(
              onTap: onBookmark,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 19.sp,
                  color: saved ? _kPrimary : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final LessonVideo part;

  const _Thumbnail({required this.part});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108.w,
      height: 68.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (part.thumbnailUrl != null)
              Image.network(
                part.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
              )
            else
              Container(color: Colors.grey.shade200),

            // A padlocked video is dimmed rather than hidden: it is what the
            // free one is a sample of.
            if (!part.isOpen)
              Container(color: Colors.black.withValues(alpha: 0.45)),

            Center(
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  part.isOpen
                      ? Icons.play_arrow_rounded
                      : Icons.lock_rounded,
                  size: 15.sp,
                  color: Colors.white,
                ),
              ),
            ),

            if (part.lengthLabel != null)
              Positioned(
                right: 4.w,
                bottom: 4.h,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(part.lengthLabel!,
                      style: TextStyle(fontSize: 9.sp, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
