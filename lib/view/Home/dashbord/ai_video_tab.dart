// lib/view/Home/dashbord/ai_video_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/selection_content_model.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/app_shimmer.dart';
import '../lessons/student_lesson_detail_screen.dart';

class AiVideoTab extends StatefulWidget {
  const AiVideoTab({super.key});

  @override
  State<AiVideoTab> createState() => _AiVideoTabState();
}

class _AiVideoTabState extends State<AiVideoTab> {
  static const Color kPrimary = Color(0xFF87986B);
  static const Color kBg = Color(0xFFEFF4E2);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // null = show lessons from every chapter, otherwise show only the
  // selected chapter's lessons.
  int? _selectedChapterIndex;

  @override
  void initState() {
    super.initState();
    // In case this screen is opened before the content has loaded
    // elsewhere (e.g. deep link), make sure we have the data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SelectionContentProvider>();
      if (provider.content == null && !provider.isLoading) {
        provider.loadContent();
      }
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentLessonModel> _visibleLessons(List<StudentChapterModel> chapters) {
    List<StudentLessonModel> lessons;

    if (_selectedChapterIndex != null && _selectedChapterIndex! < chapters.length) {
      lessons = chapters[_selectedChapterIndex!].lessons;
    } else {
      lessons = chapters.expand((c) => c.lessons).toList();
    }

    // Videos and notes only — quiz lessons belong in QBank, not here.
    lessons = lessons.where((l) => l.isWatchable).toList();

    if (_searchQuery.isEmpty) return lessons;

    return lessons.where((l) => l.title.toLowerCase().contains(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: Colors.black,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "AI Videos",
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
            ),
            Text(
              "Learn from AI-powered medical lessons",
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      body: Consumer<SelectionContentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.content == null) {
            return const ScreenShimmer(layout: ShimmerLayout.rows);
          }

          if (provider.errorMessage != null && provider.content == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.errorMessage!, textAlign: TextAlign.center),
                    SizedBox(height: 12.h),
                    ElevatedButton(onPressed: () => provider.loadContent(), child: const Text("Retry")),
                  ],
                ),
              ),
            );
          }

          final content = provider.content;
          final chapters = content?.chapters ?? const <StudentChapterModel>[];

          if (chapters.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  "No chapters available yet.",
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
                ),
              ),
            );
          }

          final lessons = _visibleLessons(chapters);

          return RefreshIndicator(
            onRefresh: () => provider.loadContent(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search bar ──
                  Container(
                    width: double.infinity,
                    height: 46.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30.r)),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search videos, chapters ....",
                              hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: TextStyle(fontSize: 13.sp, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 22.h),

                  // ── Chapters (horizontal) ──
                  Text(
                    "Chapters",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    // Square-ish: height tracks the card's own width so it
                    // scales on the SAME axis as everything inside it, which
                    // is all sized in .w/.sp. The old fixed 130.h was both
                    // too short for the contents (icon + 2-line title + the
                    // lessons pill + the optional premium badge need ~140)
                    // and scaled on the opposite axis, so it burst in
                    // portrait and again, much harder, in landscape.
                    height: 150.w,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: chapters.length,
                      separatorBuilder: (_, __) => SizedBox(width: 12.w),
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final isSelected = _selectedChapterIndex == index;
                        final isPremiumChapter = chapter.lessons.any((l) => l.isPremium);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedChapterIndex = isSelected ? null : index;
                            });
                          },
                          child: Container(
                            width: 150.w,
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: isSelected ? kPrimary : Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28.w,
                                  height: 28.w,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : kPrimary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.menu_book_rounded, size: 14.sp, color: kPrimary),
                                ),
                                const Spacer(),
                                // Plain Text, not Flexible: Flexible clamps the
                                // box by height and ellipsis works on line
                                // count, so a squeezed Flexible slices the
                                // second line in half instead of ellipsizing.
                                // The card is sized to fit two lines outright.
                                Text(
                                  chapter.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withOpacity(0.2)
                                            : kPrimary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        "${chapter.lessons.length} Lessons",
                                        style: TextStyle(
                                          fontSize: 9.5.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? Colors.white : kPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isPremiumChapter) ...[
                                  SizedBox(height: 4.h),
                                  Text(
                                    "PREMIUM",
                                    style: TextStyle(
                                      fontSize: 8.5.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: isSelected ? Colors.white.withOpacity(0.85) : Colors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 26.h),

                  // ── Lessons (vertical) ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedChapterIndex != null
                            ? chapters[_selectedChapterIndex!].title
                            : "All lessons",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                      ),
                      if (_selectedChapterIndex != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedChapterIndex = null),
                          child: Text(
                            "View all",
                            style: TextStyle(fontSize: 12.5.sp, color: kPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  if (lessons.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? "No lessons match \"$_searchQuery\"."
                            : "No lessons available yet.",
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: lessons.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];

                        return GestureDetector(
                          // Locked lessons open too: the detail screen shows
                          // the plans paywall. A snackbar here used to swallow
                          // the tap, so a pro video had no way to sell itself.
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentLessonDetailScreen(
                                  lesson: lesson,
                                  relatedLessons: lessons, // all currently-visible lessons become "related"
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(10.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Thumbnail ──
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: lesson.thumbnailUrl != null
                                          ? Image.network(
                                              lesson.thumbnailUrl!,
                                              width: 92.w,
                                              height: 72.h,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(width: 92.w, height: 72.h, color: kPrimary),
                                    ),
                                    if (lesson.hasVideo)
                                      Positioned.fill(
                                        child: Center(
                                          child: Container(
                                            padding: EdgeInsets.all(5.w),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.35),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.play_arrow_rounded,
                                              size: 16.sp,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (lesson.locked)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: EdgeInsets.all(3.w),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.lock_rounded, size: 10.sp, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(width: 12.w),

                                // ── Title / description / access type ──
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lesson.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                      if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                                        SizedBox(height: 4.h),
                                        Text(
                                          lesson.description!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade600),
                                        ),
                                      ],
                                      SizedBox(height: 6.h),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: lesson.isPremium
                                              ? Colors.orange.withOpacity(0.12)
                                              : Colors.green.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8.r),
                                        ),
                                        child: Text(
                                          lesson.accessType.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w700,
                                            color: lesson.isPremium ? Colors.orange : Colors.green,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Icon(Icons.bookmark_border_rounded, size: 18.sp, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
