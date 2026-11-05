// lib/view/Home/dashbord/videos_subjects_screen.dart
//
// "Videos — learn anytime, at your own pace."
//
// The top of the video section, as the design draws it: the chapters as
// chips across the top, and the subjects under the chosen one as cards, each
// saying how many videos are inside it.
//
// A subject is a lesson. A lesson used to be one video and is a container of
// them now, which is exactly what a card promising "8 Videos" needs.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/refresh_on_visible.dart';
import '../../../models/selection_content_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/access_chip.dart';
import '../../../widget/app_loading.dart';
import '../../../widget/app_refresh.dart';
import 'lesson_videos_screen.dart';

const Color _kBg = Color(0xFFEFF4E2);
const Color _kPrimary = Color(0xFF87986B);

class VideosSubjectsScreen extends StatefulWidget {
  const VideosSubjectsScreen({super.key});

  /// The lessons of a chapter that belong in the video section: videos and
  /// notes, never quizzes — those live in QBank.
  static List<StudentLessonModel> subjectsIn(StudentChapterModel chapter) =>
      chapter.lessons.where((l) => l.isWatchable).toList();

  /// How many videos a subject holds. One for a lesson the server still
  /// sends as a single video, which is what [videoParts] stands in.
  static int videoCount(StudentLessonModel lesson) => lesson.videoParts.length;

  @override
  State<VideosSubjectsScreen> createState() => _VideosSubjectsScreenState();
}

class _VideosSubjectsScreenState extends State<VideosSubjectsScreen>
    with RefreshOnVisible<VideosSubjectsScreen> {
  int _chapter = 0;
  String _query = '';

  @override
  Future<void> onRefresh() async {
    if (!mounted) return;
    await context.read<SelectionContentProvider>().loadContent();
  }

  List<StudentLessonModel> _subjects(List<StudentChapterModel> chapters) {
    if (chapters.isEmpty) return const [];
    final chapter = chapters[_chapter.clamp(0, chapters.length - 1)];
    final subjects = VideosSubjectsScreen.subjectsIn(chapter);

    if (_query.isEmpty) return subjects;
    return subjects
        .where((l) => l.title.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<SelectionContentProvider>();
    final chapters = content.content?.chapters ?? const <StudentChapterModel>[];
    final subjects = _subjects(chapters);

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
            Text('Videos',
                style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            Text('Learn anytime, at your own pace',
                style:
                    TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: content.isLoading && content.content == null
          ? const AppLoading()
          : AppRefresh(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                children: [
                  _SubjectSearch(
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                  ),
                  SizedBox(height: 18.h),
                  if (chapters.isNotEmpty) ...[
                    Text('Subjects',
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87)),
                    SizedBox(height: 10.h),
                    SizedBox(
                      height: 36.h,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: chapters.length,
                        separatorBuilder: (_, __) => SizedBox(width: 8.w),
                        itemBuilder: (context, i) => _ChapterChip(
                          title: chapters[i].title,
                          selected: i == _chapter,
                          onTap: () => setState(() => _chapter = i),
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                  ],
                  if (subjects.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 44.h),
                      child: Text(
                        chapters.isEmpty
                            ? 'No subjects published yet.'
                            : _query.isEmpty
                                ? 'No videos in this subject yet.'
                                : 'No subjects match "$_query".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13.sp, color: Colors.grey.shade600),
                      ),
                    )
                  else
                    for (final subject in subjects) ...[
                      _SubjectCard(
                        subject: subject,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LessonVideosScreen(lesson: subject),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                ],
              ),
            ),
    );
  }
}

class _SubjectSearch extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SubjectSearch({required this.onChanged});

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
                hintText: 'Search videos',
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

class _ChapterChip extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ChapterChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: selected ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: selected ? _kPrimary : Colors.grey.shade300),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

/// One subject: its name, how many videos are in it, and the way in.
class _SubjectCard extends StatelessWidget {
  final StudentLessonModel subject;
  final VoidCallback onTap;

  const _SubjectCard({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = VideosSubjectsScreen.videoCount(subject);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 13.h, 10.w, 13.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_circle_outline_rounded,
                  size: 21.sp, color: _kPrimary),
            ),
            SizedBox(width: 13.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.sp,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Text('$count ${count == 1 ? 'Video' : 'Videos'}',
                          style: TextStyle(
                              fontSize: 11.5.sp, color: Colors.grey.shade600)),
                      SizedBox(width: 8.w),
                      // A subject with a free part and paid ones is neither
                      // Free nor Premium — it is a sample.
                      if (subject.hasFreePreviewParts)
                        Text(
                          '${subject.openPartCount} free · '
                          '${subject.lockedPartCount} premium',
                          style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF3F7D34)),
                        )
                      else
                        AccessChip(accessType: subject.accessType),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 22.sp, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
