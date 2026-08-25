// lib/view/Home/Qbank/qbank_tab.dart
//
// QBank entry point: the topics of the student's selected exam course.
// Only topics that actually contain quiz lessons are listed.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../models/selection_content_model.dart';
import '../../../repository/selection_content_provider.dart';
import 'qbank_subjects_screen.dart';
import '../../../widget/app_shimmer.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kBg = Color(0xFFEFF4E2);

class QbankTab extends StatefulWidget {
  const QbankTab({super.key});

  @override
  State<QbankTab> createState() => _QbankTabState();
}

class _QbankTabState extends State<QbankTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SelectionContentProvider>();
      if (provider.content == null && !provider.isLoading) {
        provider.loadContent();
      }
    });

    _searchController.addListener(
      () => setState(() => _query = _searchController.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// A topic only belongs in QBank if at least one of its lessons is a quiz.
  List<StudentChapterModel> _topics(SelectionContentModel? content) {
    final chapters = content?.chapters ?? const <StudentChapterModel>[];
    final withQuizzes = chapters.where((c) => c.lessons.any((l) => l.isQuiz));

    if (_query.isEmpty) return withQuizzes.toList();

    return withQuizzes
        .where((c) =>
            c.title.toLowerCase().contains(_query) ||
            c.lessons.any((l) => l.isQuiz && l.title.toLowerCase().contains(_query)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        foregroundColor: Colors.black,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Consumer<SelectionContentProvider>(
          builder: (context, provider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "QBank",
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: Colors.black),
                ),
                Text(
                  provider.content?.course?.title ?? "Core clinical subjects for prometric exams",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
                ),
              ],
            );
          },
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
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(provider.errorMessage!, textAlign: TextAlign.center),
                    SizedBox(height: 12.h),
                    ElevatedButton(
                      onPressed: provider.loadContent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }

          final topics = _topics(provider.content);

          return RefreshIndicator(
            color: _kPrimary,
            onRefresh: provider.loadContent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Search ──
                  Container(
                    width: double.infinity,
                    height: 50.h,
                    padding: EdgeInsets.symmetric(horizontal: 18.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search subjects, topics",
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

                  SizedBox(height: 18.h),

                  // ── Bookmarks / Continue MCQs (UI only — no endpoint yet) ──
                  Row(
                    children: [
                      const Expanded(
                        child: _ShortcutCard(
                          icon: Icons.bookmark_border_rounded,
                          title: "Bookmarks",
                          subtitle: "0 Bookmarks",
                        ),
                      ),
                      SizedBox(width: 14.w),
                      const Expanded(
                        child: _ShortcutCard(
                          icon: Icons.assignment_outlined,
                          title: "Continue\nMCQs",
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  Text(
                    "Topics",
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  SizedBox(height: 12.h),

                  if (topics.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 28.h),
                      child: Text(
                        _query.isNotEmpty
                            ? "No topics match \"$_query\"."
                            : "No MCQ topics in your selected course yet.",
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: topics.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        final subjectCount = topic.lessons.where((l) => l.isQuiz).length;

                        return QbankRowTile(
                          icon: Icons.menu_book_rounded,
                          title: topic.title,
                          subtitle: "$subjectCount ${subjectCount == 1 ? 'Subject' : 'Subjects'}",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QbankSubjectsScreen(chapter: topic),
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
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _ShortcutCard({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 165.h,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: const BoxDecoration(color: _kBg, shape: BoxShape.circle),
            child: Icon(icon, size: 22.sp, color: _kPrimary),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 6.h),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

// Placeholder so home_screen.dart's `case 2` compiles until the real
// Tests screen exists.
class TestsTab extends StatelessWidget {
  const TestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Tests — coming soon")),
    );
  }
}
