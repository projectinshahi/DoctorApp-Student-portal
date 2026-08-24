import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenProfile;

  const HomeTab({super.key, required this.onOpenProfile});

  static const Color kPrimary = Color(0xFF87986B);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─────────────────────────────────────────────
          // Header
          // ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            height: 250.h,
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(35.r)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32.w,
                      height: 40.h,
                      child: IconButton(
                        onPressed: onOpenProfile,
                        icon: Image.asset(
                          'asset/icons/drawer_icon.png',
                          width: 23.33.w,
                          height: 16.67.h,
                          fit: BoxFit.contain,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    SizedBox(width: 20.w),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Heyyy",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          Text(
                            "Dr. David Thomson",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),
                    const _HeaderIconButton(icon: Icons.bookmark_border_rounded),
                    SizedBox(width: 10.w),
                    const _HeaderIconButton(icon: Icons.notifications_none_rounded),
                  ],
                ),
                SizedBox(height: 32.h),
                Container(
                  width: double.infinity,
                  height: 50.h,
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20.sp),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          "Search MCQ IDs, Pearl IDs, topics ....",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),

                // ── Welcome back card ──
                Container(
                  width: double.infinity,
                  height: 165.h,
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E7E7),
                    borderRadius: BorderRadius.circular(24.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Welcome back Doctor",
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        "Consistency today, success\ntomorrow, Keep going!!",
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.grey.shade600,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white, thickness: 1),
                            Text(
                              "0 Modules completed",
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Image.asset('asset/icons/banner_icon.png'),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 26.h),

                // ── Continue MCQs ──
                Text(
                  "Continue MCQs",
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "A 6-month-old presented with a genetic disorder "
                            "attributed to multifactorial inheritance. This type "
                            "of inheritance is most likely to play a significant "
                            "role in which of the following disorder?",
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      const _McqOption(label: "A", text: "Achondroplasia"),
                      SizedBox(height: 10.h),
                      const _McqOption(label: "B", text: "Lysosomal storage disease"),
                      SizedBox(height: 10.h),
                      const _McqOption(label: "c", text: "Lysosomal storage disease"),
                      SizedBox(height: 10.h),
                      const _McqOption(label: "B", text: "Lysosomal storage disease"),
                    ],
                  ),
                ),

                SizedBox(height: 28.h),

                // ── Continue Learning ──
                Text(
                  "Continue Learning",
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    const Expanded(
                      child: _LearningCard(title: "DHA Case : Chest pain inferior STEMI"),
                    ),
                    SizedBox(width: 12.w),
                    const Expanded(
                      child: _LearningCard(
                        title: "Cardiology – Ischemic Heart Disease",
                        icon: Icons.favorite_rounded,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 28.h),

                // ── AI picks for you ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "AI picks for you",
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    const Expanded(
                      child: _AiPickCard(
                        icon: Icons.play_arrow_rounded,
                        tagText: "Recommended video",
                        title: "Inferior STEMI walkthrough",
                        subtitle: "Cardiology",
                      ),
                    ),
                    SizedBox(width: 12.w),
                    const Expanded(
                      child: _AiPickCard(
                        icon: Icons.bloodtype_rounded,
                        tagText: "Weak area - practice",
                        title: "Hematology rapid fire MCQs",
                        subtitle: "Hematology",
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header icon button (bookmark / bell) ──
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  const _HeaderIconButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(icon, size: 20.sp, color: const Color(0xFF87986B)),
    );
  }
}

// ── MCQ answer option row ──
class _McqOption extends StatelessWidget {
  final String label;
  final String text;
  const _McqOption({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F1),
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13.r,
            backgroundColor: Colors.white,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continue Learning card ──
class _LearningCard extends StatelessWidget {
  final String title;
  final IconData icon;
  const _LearningCard({required this.title, this.icon = Icons.play_arrow_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130.h,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF87986B),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 16.sp, color: const Color(0xFF87986B)),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.white, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ── AI picks card ──
class _AiPickCard extends StatelessWidget {
  final IconData icon;
  final String tagText;
  final String title;
  final String subtitle;

  const _AiPickCard({
    required this.icon,
    required this.tagText,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF87986B),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 15.sp, color: const Color(0xFF87986B)),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 10.sp, color: Colors.white),
                    SizedBox(width: 2.w),
                    Text("AI", style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(tagText, style: TextStyle(fontSize: 10.5.sp, color: Colors.white.withOpacity(0.75))),
          SizedBox(height: 4.h),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
          ),
          SizedBox(height: 4.h),
          Text(subtitle, style: TextStyle(fontSize: 11.sp, color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }
}