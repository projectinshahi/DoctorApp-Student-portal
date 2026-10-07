// lib/widget/access_chip.dart
//
// "Free" or "Premium" on a lesson row — the same two chips the admin panel
// shows, so what an admin sets is what a student sees.
//
// It says what the lesson IS, not whether this student can open it. The lock
// beside it answers that: a premium lesson a subscriber has paid for carries
// the chip and no lock.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AccessChip extends StatelessWidget {
  /// `free` or `premium`, as the server sends it. Anything else draws
  /// nothing — a new value is not worth a wrong label.
  final String accessType;

  const AccessChip({super.key, required this.accessType});

  static const Color _premium = Color(0xFFB4780A);
  static const Color _free = Color(0xFF3F7D34);

  @override
  Widget build(BuildContext context) {
    final type = accessType.toLowerCase();
    if (type != 'free' && type != 'premium') return const SizedBox.shrink();

    final premium = type == 'premium';
    final tint = premium ? _premium : _free;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        premium ? 'Premium' : 'Free',
        style: TextStyle(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: tint,
        ),
      ),
    );
  }
}
