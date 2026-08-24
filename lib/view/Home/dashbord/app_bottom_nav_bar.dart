import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color primaryColor;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.primaryColor,
  });

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: "Home"),
    _NavItemData(icon: Icons.help_outline_rounded, label: "QBank"),
    _NavItemData(icon: Icons.description_outlined, label: "Tests"),
    _NavItemData(icon: Icons.play_circle_outline_rounded, label: "AI Videos"),
    _NavItemData(icon: Icons.person_outline_rounded, label: "Profile"),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Container(
        height: 75.h,
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            return _NavItem(
              icon: item.icon,
              label: item.label,
              isSelected: currentIndex == index,
              onTap: () => onTap(index),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 25.sp,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp, // NOTE: was 18.sp in your original - almost
              // certainly a typo, since 18sp for a bottom-nav label would
              // be enormous. Fixed to a sane label size; bump back if
              // that was intentional.
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}