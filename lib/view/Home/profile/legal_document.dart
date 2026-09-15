// lib/view/Home/profile/legal_document.dart
//
// How the Terms and the Privacy Policy read.
//
// Short, and written from the Scope of Work rather than from a template, so
// every line describes something this platform actually does. Nine points a
// student reads in a minute beat eighteen sections they scroll past, which
// protect nobody.
//
// Cards, now that the points are short — the earlier prose layout was built
// for eighteen long sections, where boxing each one cut a single argument
// into pieces. A short point is its own argument, so a card fits it.
//
// Shared by both documents so the two cannot drift apart: they are read back
// to back, and a reader should not be able to tell they were built at
// different times.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theam /app_color.dart';
import 'legal_text.dart';

/// One point. An icon, a heading, and two or three lines — a point that needs
/// a paragraph is usually two points.
class LegalPoint {
  final IconData icon;
  final String title;
  final String body;

  const LegalPoint({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class LegalScaffold extends StatelessWidget {
  final String title;

  /// One line under the title saying what the document is for.
  final String subtitle;

  final List<LegalPoint> points;

  /// The sentence the reader is agreeing to, set apart at the foot.
  final String closing;

  /// Support or privacy — a privacy request may need to reach someone else.
  final String contactEmail;

  const LegalScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.closing,
    required this.contactEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      // The header runs under the app bar, so the green reaches the status
      // bar instead of stopping at an arbitrary line below it.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded,
              size: 30.sp, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(title: title, subtitle: subtitle, count: points.length),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 34.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driven by the values themselves, so it cannot be left up
                // after they are filled, or forgotten while they are not.
                if (LegalDetails.isIncomplete) ...[
                  const LegalDraftBanner(),
                  SizedBox(height: 16.h),
                ],

                for (var i = 0; i < points.length; i++) ...[
                  _PointCard(number: i + 1, point: points[i]),
                  if (i < points.length - 1) SizedBox(height: 12.h),
                ],

                SizedBox(height: 22.h),
                _Agreement(text: closing),
                SizedBox(height: 14.h),
                _Contact(email: contactEmail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The title block. Deep green, so the document opens on something other than
/// a wall of text and the reader knows which of the two they are in.
class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          22.w, MediaQuery.of(context).padding.top + 62.h, 22.w, 28.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6E8052), AppColor.buttoncolor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                  color: Colors.white)),
          SizedBox(height: 9.h),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.55,
                  color: Colors.white.withValues(alpha: 0.88))),
          SizedBox(height: 16.h),
          Row(
            children: [
              _Pill(text: '$count points'),
              SizedBox(width: 8.w),
              _Pill(text: 'Updated ${LegalDetails.lastUpdated}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  final int number;
  final LegalPoint point;

  const _PointCard({required this.number, required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 17.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D4A2C).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColor.buttoncolor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13.r),
            ),
            child: Icon(point.icon, size: 20.sp, color: AppColor.buttoncolor),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The number sits with the title rather than in a badge of
                    // its own: it orders the points without competing with
                    // the icon for attention.
                    Text('${number.toString().padLeft(2, '0')}  ',
                        style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.6,
                            letterSpacing: 0.5,
                            color: AppColor.buttoncolor
                                .withValues(alpha: 0.75))),
                    Expanded(
                      child: Text(point.title,
                          style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              color: Colors.black87)),
                    ),
                  ],
                ),
                SizedBox(height: 7.h),
                Text(point.body,
                    style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.6,
                        color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Agreement extends StatelessWidget {
  final String text;

  const _Agreement({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColor.buttoncolor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
        border:
            Border.all(color: AppColor.buttoncolor.withValues(alpha: 0.26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined,
              size: 19.sp, color: AppColor.buttoncolor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3D4A2C))),
          ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  final String email;

  const _Contact({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 9.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Questions about this?',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          SizedBox(height: 12.h),
          _ContactRow(
              icon: Icons.business_outlined,
              value: LegalDetails.companyName),
          _ContactRow(icon: Icons.mail_outline_rounded, value: email),
          _ContactRow(
              icon: Icons.language_rounded, value: LegalDetails.website),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: 11.h),
        child: Row(
          children: [
            Icon(icon, size: 16.sp, color: Colors.grey.shade500),
            SizedBox(width: 11.w),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13.sp, color: Colors.grey.shade800)),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
}

class LegalDraftBanner extends StatelessWidget {
  const LegalDraftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A33D).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 17.sp, color: const Color(0xFF9A6B18)),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'The company name, contact details and date are still to be '
              'filled in before release.',
              style: TextStyle(
                  fontSize: 11.5.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8A5B18)),
            ),
          ),
        ],
      ),
    );
  }
}
