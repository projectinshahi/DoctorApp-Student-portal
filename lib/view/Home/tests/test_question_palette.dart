// lib/view/Home/tests/test_question_palette.dart
//
// The question navigator: every question as a numbered box, coloured by what
// the student has done with it, and tappable to jump straight there.
//
// This is how a paper is actually sat — answer the easy ones, star the rest,
// then come back. Walking there with Next/Previous makes that unusable at 40
// questions, so navigation lives here and the paper itself keeps one button.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../repository/test_provider.dart';

const Color _kPrimary = Color(0xFF87986B);
const Color _kMarked = Color(0xFFE8A33D);

class TestQuestionPalette extends StatelessWidget {
  /// Submits the paper. Owned by the attempt screen, which is what knows how
  /// to confirm and where to go afterwards.
  final Future<void> Function() onSubmit;

  const TestQuestionPalette({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TestProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timer_outlined,
                size: 16.sp,
                color: provider.isTimeUp ? Colors.red.shade600 : Colors.black87),
            SizedBox(width: 6.w),
            Text(
              provider.isTimeUp ? "Time's up" : provider.formattedTime,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: provider.isTimeUp ? Colors.red.shade600 : Colors.black87,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.close_rounded, size: 24.sp, color: Colors.black87),
          ),
        ],
      ),
      body: Column(
        children: [
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 14.h),
          Text('Currently attempting question ${provider.currentIndex + 1}',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
          SizedBox(height: 14.h),
          const _Legend(),
          SizedBox(height: 14.h),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1.55,
              ),
              itemCount: provider.questions.length,
              itemBuilder: (context, index) => _NumberBox(
                number: index + 1,
                state: provider.stateAt(index),
                isCurrent: index == provider.currentIndex,
                onTap: () {
                  provider.goTo(index);
                  Navigator.maybePop(context);
                },
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
            child: SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: provider.isSubmitting
                    ? null
                    : () async {
                        // Close the navigator first: the confirm dialog and
                        // the result screen both belong to the paper.
                        Navigator.maybePop(context);
                        await onSubmit();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kPrimary.withValues(alpha: 0.5),
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
                ),
                child: Text('SUBMIT',
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16.w,
      runSpacing: 8.h,
      alignment: WrapAlignment.center,
      children: const [
        _LegendChip(color: _kPrimary, label: 'Answered'),
        _LegendChip(color: _kMarked, label: 'Marked'),
        _LegendChip(color: Colors.white, label: 'Not answered', bordered: true),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool bordered;

  const _LegendChip(
      {required this.color, required this.label, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.r),
            border: bordered ? Border.all(color: Colors.grey.shade400) : null,
          ),
        ),
        SizedBox(width: 6.w),
        Text(label,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700)),
      ],
    );
  }
}

class _NumberBox extends StatelessWidget {
  final int number;
  final QuestionState state;
  final bool isCurrent;
  final VoidCallback onTap;

  const _NumberBox({
    required this.number,
    required this.state,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (state) {
      QuestionState.answered => (_kPrimary, Colors.white),
      QuestionState.marked => (_kMarked, Colors.white),
      QuestionState.unanswered => (Colors.white, Colors.grey.shade800),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8.r),
          // The one you are on is outlined rather than recoloured, so it can
          // still show whether it is answered.
          border: Border.all(
            color: isCurrent ? Colors.black87 : Colors.grey.shade300,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Text('$number',
            style: TextStyle(
                fontSize: 17.sp, fontWeight: FontWeight.w600, color: foreground)),
      ),
    );
  }
}
