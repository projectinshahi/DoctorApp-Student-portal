// lib/view/Home/profile/info_screens.dart
//
// The remaining profile entries: Learn more, FAQ, Contact us, Terms, Share.
//
// **The wording here is placeholder.** It is structured and readable so the
// screens are usable now, but the FAQ answers, the contact details and the
// terms are demo copy — they must be replaced with the academy's real ones
// before release. Terms in particular are a legal document, not something an
// app developer writes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theam /app_color.dart';
import '../../../widget/app_snackbar.dart';

/// Shared frame, so five screens cannot drift into five different headers.
class _InfoScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      appBar: AppBar(
        backgroundColor: AppColor.Screenbackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded, size: 30.sp, color: Colors.black),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
        children: children,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

Widget _body(String text) => Text(text,
    style: TextStyle(fontSize: 13.sp, height: 1.55, color: Colors.grey.shade800));

Widget _heading(String text) => Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(text,
          style: TextStyle(
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87)),
    );

// ── Learn more ───────────────────────────────────────────────
class LearnMoreScreen extends StatelessWidget {
  const LearnMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Learn more',
      children: [
        _Panel(children: [
          _heading('About Dr. SKM\'s Academy'),
          _body(
            'Structured preparation for the Gulf licensing exams — DHA, MOH, '
            'HAAD, Prometric and NEET-PG — built around video lessons, notes '
            'and question practice.',
          ),
        ]),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('How the app is organised'),
          _body(
            'Home keeps what you are part-way through, plus the MCQ of the Day.\n\n'
            'QBank holds the question banks by subject, with your bookmarks.\n\n'
            'Tests are timed grand tests — one attempt each, so treat them as '
            'the real thing.\n\n'
            'AI Videos is the full lesson library for your selected course.',
          ),
        ]),
      ],
    );
  }
}

// ── FAQ ──────────────────────────────────────────────────────
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = <({String q, String a})>[
    (
      q: 'Can I retake a grand test?',
      a: 'No. Each test allows one attempt, which is what makes the score and '
          'the leaderboard mean anything. The timer starts when you begin and '
          'cannot be paused — it keeps running if you close the app.',
    ),
    (
      q: 'Does my video progress save?',
      a: 'Yes. Your position is sent to the server every few seconds and when '
          'you leave, so reopening a lesson resumes where you stopped, on any '
          'device signed in to your account.',
    ),
    (
      q: 'When does the MCQ of the Day change?',
      a: 'At midnight Gulf time. Everyone on your course gets the same ten '
          'questions each day, and finishing keeps your streak going.',
    ),
    (
      q: 'Why can I not take a screenshot?',
      a: 'Course content is protected. Screenshots and screen recording are '
          'blocked throughout the app, and playback stops if recording or '
          'screen mirroring is detected.',
    ),
    (
      q: 'What happens to my bookmarks if I change device?',
      a: 'They follow your account. Bookmarks are stored on the server, not on '
          'the phone.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'FAQ',
      children: [
        for (final faq in _faqs) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Theme(
              // The default expansion tile draws grey divider lines that cut
              // across the rounded card.
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(faq.q,
                    style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                iconColor: AppColor.buttoncolor,
                collapsedIconColor: Colors.grey.shade600,
                childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [_body(faq.a)],
              ),
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}

// ── Contact us ───────────────────────────────────────────────
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Contact us',
      children: [
        _Panel(children: [
          _heading('We usually reply within one working day'),
          _body('Tell us your registered email and the course you are on — it '
              'saves a round trip.'),
        ]),
        SizedBox(height: 12.h),
        // Tapping copies to the clipboard rather than opening a mail or dial
        // app: url_launcher is not a dependency, and Clipboard ships with
        // Flutter. A row that looks tappable and does nothing is worse than
        // one that plainly copies.
        _ContactRow(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: 'erp.shahisolutions@gmail.com',
        ),
        SizedBox(height: 10.h),
        _ContactRow(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: '+91 00000 00000',
        ),
        SizedBox(height: 10.h),
        _ContactRow(
          icon: Icons.schedule_rounded,
          label: 'Hours',
          value: 'Sunday to Thursday, 9am – 6pm',
          copyable: false,
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: copyable
          ? () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                showAppSnackBar(context, '$label copied');
              }
            }
          : null,
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19.sp, color: AppColor.buttoncolor),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.sp, color: Colors.grey.shade600)),
                  SizedBox(height: 2.h),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ],
              ),
            ),
            if (copyable)
              Icon(Icons.copy_rounded, size: 16.sp, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ── Terms & Conditions ───────────────────────────────────────
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Terms & Conditions',
      children: [
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFE8A33D).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17.sp, color: const Color(0xFF9A6B18)),
              SizedBox(width: 9.w),
              Expanded(
                child: Text(
                  'Placeholder text. Replace with the academy\'s own terms '
                  'before release.',
                  style: TextStyle(
                      fontSize: 11.5.sp,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A5B18)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('1. Your account'),
          _body('Your login is personal. Sharing it, or signing in on a '
              'device you do not control, may end your access.'),
          SizedBox(height: 14.h),
          _heading('2. Course content'),
          _body('Videos, notes and questions are licensed to you for personal '
              'study. Recording, copying, redistributing or reselling them is '
              'not permitted.'),
          SizedBox(height: 14.h),
          _heading('3. Subscriptions'),
          _body('Paid plans grant access for the stated period. Refunds follow '
              'the policy shown at the time of purchase.'),
          SizedBox(height: 14.h),
          _heading('4. Fair use'),
          _body('Automated access, scraping and attempts to bypass the app\'s '
              'content protections are grounds for suspension.'),
        ]),
      ],
    );
  }
}

// ── Share this app ───────────────────────────────────────────
// ── Privacy Policy ───────────────────────────────────────────
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _InfoScaffold(
      title: 'Privacy Policy',
      children: [
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFE8A33D).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17.sp, color: const Color(0xFF9A6B18)),
              SizedBox(width: 9.w),
              Expanded(
                child: Text(
                  // Same warning the Terms screen carries, and for the same
                  // reason: this is a legal document, and app stores reject
                  // builds whose privacy policy does not match what the app
                  // actually collects.
                  'Placeholder text. Replace with the academy\'s own policy, '
                  'reviewed against what the app actually collects, before '
                  'release.',
                  style: TextStyle(
                      fontSize: 11.5.sp,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8A5B18)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('What we collect'),
          _body('Your name and email address, from the Google account you '
              'sign in with.\n\n'
              'A device identifier, so the app can tell your devices apart '
              'and keep one session signed in at a time.\n\n'
              'Your study activity: which lessons you have watched and how '
              'far, your question and test answers, scores, and bookmarks.'),
        ]),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('What we use it for'),
          _body('To show your progress and pick up where you left off, to '
              'mark your tests and place you on the leaderboard, and to keep '
              'your account to one device at a time.\n\n'
              'We do not sell your data, and we do not use it for '
              'advertising.'),
        ]),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('What is stored on your phone'),
          _body('Your sign-in tokens, the device identifier, and small '
              'preferences such as your default playback speed.\n\n'
              'Signing out removes the tokens. The device identifier stays, '
              'because it identifies the phone rather than you.'),
        ]),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('Content protection'),
          _body('Screenshots and screen recording are blocked on course '
              'content, and playback stops if recording or screen mirroring '
              'is detected. The app checks whether the device is rooted or '
              'jailbroken.\n\n'
              'These checks look at the device, not at anything else on it. '
              'The app does not read your files, messages, contacts or other '
              'apps.'),
        ]),
        SizedBox(height: 12.h),
        _Panel(children: [
          _heading('Your choices'),
          _body('To have your account and study history deleted, contact us '
              'from the Contact us screen using your registered email.'),
        ]),
      ],
    );
  }
}
