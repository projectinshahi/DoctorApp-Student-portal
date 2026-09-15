// lib/widget/quiz_loading.dart
//
// What a student looks at while a quiz is being opened.
//
// Measured on device, startAttempt takes 1.5-4.5s and none of it is the app's
// to remove — the questions do not exist until the server creates the
// attempt. So this is about the wait reading as work rather than as nothing.
//
// Two question lines and four option pills, in the shape a question actually
// has, filled in turn by the shared LoadingWave.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'loading_wave.dart';

class QuizLoading extends StatelessWidget {
  /// What is being prepared. Short and concrete — a quiz opening should read
  /// differently from a result being scored.
  final String message;

  const QuizLoading({super.key, this.message = 'Preparing your questions…'});

  /// Four is the usual MCQ shape, so the real question lands in roughly the
  /// space this occupied.
  static const int _options = 4;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: LoadingWave(
          steps: _options + 1,
          builder: (context, lift) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The question, a little wider than the options under it.
              WaveBar(height: 13.h, radius: 7.r, lift: lift(0)),
              SizedBox(height: 9.h),
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.7,
                  child: WaveBar(height: 13.h, radius: 7.r, lift: lift(0)),
                ),
              ),
              SizedBox(height: 22.h),
              for (var i = 0; i < _options; i++) ...[
                WaveBar(height: 44.h, radius: 22.r, lift: lift(i + 1)),
                SizedBox(height: 11.h),
              ],
              SizedBox(height: 14.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
