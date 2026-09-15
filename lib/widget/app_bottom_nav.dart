// lib/widget/app_bottom_nav.dart
//
// The floating tab bar.
//
// Its own file because two places draw it now — home, and every Rapid Recall
// screen — and two hand-copied bars would drift the first time a tab changed.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theam /app_color.dart';

class AppBottomNav extends StatelessWidget {
  /// 0 Home · 1 QBank · 2 Tests · 3 AI Videos · 4 Recall.
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<(IconData, String)> _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.help_outline_rounded, 'QBank'),
    (Icons.description_outlined, 'Tests'),
    (Icons.play_circle_outline_rounded, 'AI Videos'),
    (Icons.water_drop_outlined, 'Recall'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Container(
        height: 75.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: AppColor.buttoncolor,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _items.length; i++)
              _NavItem(
                icon: _items[i].$1,
                label: _items[i].$2,
                isSelected: currentIndex == i,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint =
        isSelected ? Colors.white : Colors.white.withValues(alpha: 0.55);

    // Expanded so five items divide whatever width there is, instead of each
    // taking its natural size and running off the end — "AI Videos" at 18.sp
    // overflowed by 156px even at the 440 design width.
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25.sp, color: tint),
            SizedBox(height: 3.h),
            // scaleDown keeps 18.sp wherever it fits and shrinks only the
            // labels that would not, so the bar adapts instead of clipping.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
