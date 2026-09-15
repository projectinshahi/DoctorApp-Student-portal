// lib/view/Home/profile/privacy_policy_screen.dart
//
// The Privacy Policy.
//
// Nine points describing what this platform actually stores and why, taken
// from the Functional Scope of Work. A privacy policy a student can finish is
// worth more than one that covers every hypothetical.
//
// The layout comes from legal_document.dart, shared with the Terms so the two
// cannot drift apart.
import 'package:flutter/material.dart';

import 'legal_document.dart';
import 'legal_text.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const app = LegalDetails.appName;

    return const LegalScaffold(
      title: 'Privacy Policy',
      subtitle: 'What $app stores about you, why it stores it, and who else '
          'ever sees it.',
      contactEmail: LegalDetails.privacyEmail,
      closing: 'By creating an account or continuing to use $app, you agree '
          'to your information being handled as described here.',
      points: [
        LegalPoint(
          icon: Icons.badge_outlined,
          title: 'Your account details',
          body: 'Your email address, password, display name, contact number '
              'and profile photo. If you sign in with Google or Apple, we '
              'receive the email address on that account and use it to '
              'identify you — an existing account is linked, not duplicated.',
        ),
        LegalPoint(
          icon: Icons.insights_outlined,
          title: 'What you do while learning',
          body: 'Lessons opened, how far into each video you have watched, '
              'quiz answers, scores and percentages, subject-wise '
              'performance, leaderboard rank, and any comments you post. This '
              'is what makes progress tracking, continue-learning and quiz '
              'history work.',
        ),
        LegalPoint(
          icon: Icons.receipt_long_outlined,
          title: 'Your subscription',
          body: 'Which plan you are on, when it starts and expires, and the '
              'reference and status of each payment. Card and bank details go '
              'straight to Razorpay — they never reach us and we never store '
              'them.',
        ),
        LegalPoint(
          icon: Icons.mail_outline_rounded,
          title: 'Email we send you',
          body: 'Four kinds only: a registration confirmation, a password '
              'reset link, a payment confirmation, and a reminder before your '
              'subscription expires. No marketing.',
        ),
        LegalPoint(
          icon: Icons.hub_outlined,
          title: 'Who else sees it',
          body: 'Only the services that run the platform — sign-in, the '
              'Razorpay payment gateway, the cloud that hosts and streams '
              'video, and our email provider. We do not sell your '
              'information, and we do not share it for advertising.',
        ),
        LegalPoint(
          icon: Icons.forum_outlined,
          title: 'Comments are public',
          body: 'A comment you post on a video lesson is visible to other '
              'students along with your display name, so please keep personal '
              'or confidential details out of it. You can edit or delete your '
              'own at any time.',
        ),
        LegalPoint(
          icon: Icons.lock_outline_rounded,
          title: 'How it is protected',
          body: 'Video plays through expiring links that cannot be shared, '
              'only one device can be signed in at a time, and screenshots '
              'and screen recording are blocked in the app. No system online '
              'is completely secure, and we do not claim otherwise.',
        ),
        LegalPoint(
          icon: Icons.schedule_outlined,
          title: 'How long we keep it',
          body: 'For as long as your account exists. A deactivated account '
              'loses access immediately while its progress, scores and '
              'payment records are retained. There is no self-service delete '
              'yet — email us and we will handle the request.',
        ),
        LegalPoint(
          icon: Icons.family_restroom_outlined,
          title: 'Younger students, and changes',
          body: 'This is an educational app, and a student below the age of '
              'consent in their country should use it with a parent or '
              'guardian involved. If this policy changes, the current version '
              'always lives on this screen.',
        ),
      ],
    );
  }
}
