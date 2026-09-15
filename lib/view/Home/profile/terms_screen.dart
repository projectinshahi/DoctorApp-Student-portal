// lib/view/Home/profile/terms_screen.dart
//
// The Terms & Conditions.
//
// Nine points, each one a rule the platform actually enforces — taken from the
// Functional Scope of Work, not from a template. A student who reads this has
// read the terms; sixteen sections of boilerplate only look like diligence.
//
// The layout comes from legal_document.dart, shared with the Privacy Policy
// so the two cannot drift apart.
import 'package:flutter/material.dart';

import 'legal_document.dart';
import 'legal_text.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const app = LegalDetails.appName;

    return const LegalScaffold(
      title: 'Terms & Conditions',
      subtitle: 'What you agree to when you learn with $app. '
          'Nine points, plainly put.',
      contactEmail: LegalDetails.supportEmail,
      closing: 'By creating an account or continuing to use $app, you agree '
          'to these Terms & Conditions.',
      points: [
        LegalPoint(
          icon: Icons.person_outline_rounded,
          title: 'One account, one person',
          body: 'Your email identifies your account, and only one device can '
              'be signed in at a time. Signing in somewhere new ends the '
              'earlier session. Keep your password to yourself — anything '
              'done through your account is treated as done by you.',
        ),
        LegalPoint(
          icon: Icons.workspace_premium_outlined,
          title: 'Free and premium content',
          body: 'Some courses, videos and quizzes are free; the rest need an '
              'active subscription. When a subscription expires, premium '
              'content locks again, but your progress and scores stay exactly '
              'where you left them.',
        ),
        LegalPoint(
          icon: Icons.credit_card_outlined,
          title: 'Subscriptions and payment',
          body: 'Monthly and yearly plans are paid through Razorpay, and a '
              'plan starts once the payment is confirmed. Renewal is yours to '
              'start — nothing is billed automatically. Refunds are handled '
              'through the payment gateway, outside the app.',
        ),
        LegalPoint(
          icon: Icons.timer_outlined,
          title: 'How quizzes are scored',
          body: 'The quiz timer runs on our server, so closing the app or '
              'losing signal does not pause it; you return to the same '
              'attempt with the time that is left, and it submits itself when '
              'the time runs out. One option per question, no marks lost for '
              'a question left blank, and only your best attempt counts on '
              'the leaderboard.',
        ),
        LegalPoint(
          icon: Icons.play_circle_outline_rounded,
          title: 'Video lessons',
          body: 'Videos are streamed, never downloadable. A lesson is marked '
              'complete once you have watched 90% of it, and your last '
              'position is remembered so you can pick it up on any device.',
        ),
        LegalPoint(
          icon: Icons.menu_book_outlined,
          title: 'The content stays ours',
          body: 'Courses, videos, notes and questions are for your own study. '
              'Please do not copy, record, resell or reshare them, and do not '
              'share your account with anyone else.',
        ),
        LegalPoint(
          icon: Icons.screenshot_monitor_outlined,
          title: 'Screenshots and recording',
          body: 'Screenshots and screen recording are blocked inside the app, '
              'and playback stops if a recording or screen mirror is '
              'detected. The app will not run on a rooted or jailbroken '
              'device.',
        ),
        LegalPoint(
          icon: Icons.forum_outlined,
          title: 'Comments',
          body: 'Comments on video lessons appear straight away and are '
              'reviewed afterwards. You can edit or delete your own. Anything '
              'abusive, misleading or promotional may be hidden or removed.',
        ),
        LegalPoint(
          icon: Icons.gavel_rounded,
          title: 'Misuse, and changes to these terms',
          body: 'An account used against these terms may be deactivated — '
              'access ends, records are kept. We may update these terms as '
              'the app changes, and the current version always lives on this '
              'screen.',
        ),
      ],
    );
  }
}
