import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../repository/refresh_api_provider.dart';
import 'package:provider/provider.dart';

import '../../View_model/Course_get_model.dart';
import '../../repository/course_get_provider.dart';
import '../../repository/selection_provider.dart';
import '../../widget/course_card_shimmer.dart';
import 'package:flutter/services.dart';

class ExamSelectionScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;
  final String deviceId;

  const ExamSelectionScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
    required this.deviceId,
  });

  @override
  State<ExamSelectionScreen> createState() => _ExamSelectionScreenState();
}

class _ExamSelectionScreenState extends State<ExamSelectionScreen> {
  int? selectedCourseId;
  String? selectedCourseTitle;

  int? selectedCourseTypeId;
  String? selectedCourseTypeTitle;
  int? selectedParentCourseId;
  String? selectedParentCourseTitle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseListGetProvider>().fetchCourses();
    });
  }

  // CHANGED: only treat courseTypes with status == 'published' as visible.
  // Adjust the field name (`status`) if your model calls it something else.
  bool _isPublished(dynamic item) {
    final status = item.status;
    if (status == null) return true; // fail-open if field absent
    return status.toString().toLowerCase() == 'published';
  }

  List<CourseType> _publishedCourseTypes(CourseListGetModel course) {
    return course.courseTypes.where(_isPublished).toList();
  }

  void _selectStandaloneCourse(CourseListGetModel course) {
    setState(() {
      selectedCourseId = course.id;
      selectedCourseTitle = course.title;

      selectedCourseTypeId = null;
      selectedCourseTypeTitle = null;
      selectedParentCourseId = null;
      selectedParentCourseTitle = null;
    });

    debugPrint('Selected course -> id: ${course.id}, title: "${course.title}"');
  }

  void _selectCourseType(CourseListGetModel parentCourse, CourseType courseType) {
    setState(() {
      selectedCourseTypeId = courseType.id;
      selectedCourseTypeTitle = courseType.title;
      selectedParentCourseId = parentCourse.id;
      selectedParentCourseTitle = parentCourse.title;

      selectedCourseId = null;
      selectedCourseTitle = null;
    });

    debugPrint(
      'Selected exam type -> id: ${courseType.id}, title: "${courseType.title}" '
          '(under course id: ${parentCourse.id}, title: "${parentCourse.title}")',
    );
  }

  bool get _hasSelection =>
      selectedCourseId != null || selectedCourseTypeId != null;

  Future<void> _handleDone() async {
    if (!_hasSelection) return;

    final selectionProvider = context.read<SelectionProvider>();

    // The button already dims while saving, but a fast double tap lands both
    // taps before the first rebuild — which is how the same selection was
    // being POSTed twice.
    if (selectionProvider.isSaving) return;

    bool success;
    if (selectedCourseId != null) {
      debugPrint(
        'Saving selection -> Course id: $selectedCourseId, title: "$selectedCourseTitle"',
      );
      success = await selectionProvider.selectCourse(courseId: selectedCourseId);
    } else {
      debugPrint(
        'Saving selection -> Exam type id: $selectedCourseTypeId, title: "$selectedCourseTypeTitle" '
            '(parent course id: $selectedParentCourseId, title: "$selectedParentCourseTitle")',
      );
      success = await selectionProvider.selectCourse(
        courseId: selectedParentCourseId,
        courseTypeId: selectedCourseTypeId,
      );
    }

    if (!mounted) return;

    if (success) {
      debugPrint('Selection saved successfully.');

      // Tell AuthProvider first: AuthGate is watching, and it swaps its own
      // root to the home screen.
      //
      // Not `pushAndRemoveUntil(Homescreen, false)`, which is what this used
      // to do — that removed AuthGate from the tree entirely, and AuthGate is
      // what listens for the session dying. After picking a course a
      // SESSION_ENDED then reset nothing and showed no message.
      await context.read<AuthProvider>().markExamSelected();

      if (!mounted) return;

      // Two ways in, so two ways out:
      //
      //  * pushed on top of AuthGate (from login or QBank) — pop just this
      //    route, revealing the gate, which has already become the home
      //    screen. `pop()` and not `popUntil`, so nothing else is disturbed.
      //
      //  * rendered by AuthGate as the root — there is nothing to pop, and
      //    the rebuild has already swapped it for the home screen. Popping
      //    the only route here is what would close the app.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selectionProvider.errorMessage ?? 'Failed to save selection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Back must only close the app when this screen IS the app — i.e. the
    // first-run course picker at the root. When it's pushed on top of
    // something (QBank's "Select a course" does exactly that), the old
    // unconditional SystemNavigator.pop() closed the whole app instead of
    // going back one screen.
    final isRootScreen = !Navigator.of(context).canPop();

    return PopScope(
      canPop: !isRootScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isRootScreen) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            "Your courses",
            style: TextStyle(
              color: Colors.black,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Consumer<SelectionProvider>(
                builder: (context, selectionProvider, _) {
                  return ElevatedButton(
                    onPressed: (_hasSelection && !selectionProvider.isSaving)
                        ? _handleDone
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasSelection ? Colors.black : Colors.white,
                      foregroundColor: _hasSelection ? Colors.white : Colors.grey,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: selectionProvider.isSaving
                        ? SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      "Done",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: Consumer<CourseListGetProvider>(
          builder: (context, provider, child) {
            // CHANGED: shimmer instead of a spinner while loading
            if (provider.isLoadingCourses) {
              return const CourseCardShimmer();
            }

            if (provider.coursesErrorMessage != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        provider.coursesErrorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red, fontSize: 16.sp),
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton(
                        onPressed: () => provider.fetchCourses(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            // CHANGED: filter out courses that have zero published course types
            // AND are not standalone-published themselves, so nothing empty shows.
            final visibleCourses = provider.courses.where((course) {
              final hasPublishedTypes = _publishedCourseTypes(course).isNotEmpty;
              final courseItself = course.courseTypes.isEmpty && _isPublished(course);
              return hasPublishedTypes || courseItself;
            }).toList();

            if (visibleCourses.isEmpty) {
              return Center(
                child: Text(
                  "No courses available.",
                  style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: visibleCourses.length,
              itemBuilder: (context, index) {
                final course = visibleCourses[index];
                return _buildCourseCard(course);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCourseCard(CourseListGetModel course) {
    // CHANGED: use only published course types for both the "hasCourseTypes"
    // check and the rendered list below.
    final publishedTypes = _publishedCourseTypes(course);
    final bool hasCourseTypes = publishedTypes.isNotEmpty;
    final bool isStandaloneSelected = selectedCourseId == course.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              if (!hasCourseTypes)
                GestureDetector(
                  onTap: () => _selectStandaloneCourse(course),
                  child: _SelectionCircle(isSelected: isStandaloneSelected),
                ),
            ],
          ),
          if (course.description != null &&
              course.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    course.description!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 11.sp,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "AI",
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (hasCourseTypes) ...[
            SizedBox(height: 16.h),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: publishedTypes.length, // CHANGED
              separatorBuilder: (_, __) => SizedBox(height: 14.h),
              itemBuilder: (context, index) {
                final courseType = publishedTypes[index]; // CHANGED
                final bool isSelected = selectedCourseTypeId == courseType.id;

                return InkWell(
                  onTap: () => _selectCourseType(course, courseType),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          courseType.title,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.black87,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      _SelectionCircle(isSelected: isSelected),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionCircle extends StatelessWidget {
  final bool isSelected;
  const _SelectionCircle({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 28.w,
      height: 28.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? const Color(0xFFDCDCDC) : const Color(0xFFE5E5E5),
        border: Border.all(
          color: isSelected ? const Color(0xFF8E8E8E) : Colors.transparent,
          width: 2,
        ),
      ),
      child: isSelected
          ? Icon(Icons.check, color: Colors.black87, size: 16.sp)
          : null,
    );
  }
}