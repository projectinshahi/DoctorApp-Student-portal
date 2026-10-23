// lib/widget/app_bottom_nav.dart
//
// The floating tab bar.
//
// Its own file because two places draw it now — home, and every Rapid Recall
// screen — and two hand-copied bars would drift the first time a tab changed.
//
// Sized in plain logical pixels rather than through ScreenUtil. Its .h and
// .sp are taken from the screen's *current* height, so playing a video — the
// one screen that turns the phone landscape — rescaled every one of them, and
// coming back to a portrait home left the bar squashed with its labels
// shrunk away. A tab bar is one row of five things; it does not need to
// scale with the page.
import 'package:flutter/material.dart';

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
      // Twelve from the bottom, on every screen that draws it.
      //
      // Measured from above the system's own navigation — three buttons on
      // one phone, a gesture bar on the next — because the gap a student
      // sees is the one between the bar and whatever is below it, not the
      // one to an edge hidden behind the buttons.
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColor.buttoncolor,
          borderRadius: BorderRadius.circular(30),
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
            Icon(icon, size: 23, color: tint),
            const SizedBox(height: 3),
            // scaleDown shrinks only the labels that would not otherwise
            // fit — "AI Videos" on a narrow phone — so the bar adapts
            // instead of clipping. The size it starts from is fixed, so a
            // label can no longer be scaled away to nothing.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
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
