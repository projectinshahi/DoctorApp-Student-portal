// lib/view/Home/profile/settings_screen.dart
//
// Notifications, Privacy, Support and Account.
//
// A view of SettingsProvider, which is where each switch takes effect: push
// subscribes to course alerts, the reminder schedules a daily notification,
// and sound and analytics switch their services on or off. So what this
// screen shows is what the app is doing.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/demo/demo_content.dart';
import '../../../core/theam /app_color.dart';
import '../../../repository/refresh_api_provider.dart';
import '../../../repository/settings_provider.dart';
import '../../../widget/app_snackbar.dart';
import 'info_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Must match `version:` in pubspec.yaml.
  static const String _version = '1.0.0';

  /// Shows why a switch did not stay on — permission refused.
  Future<void> _report(BuildContext context, Future<String?> change) async {
    final problem = await change;
    if (problem != null && context.mounted) {
      showAppSnackBar(context, problem, kind: AppMessage.failure);
    }
  }

  Future<void> _pickReminderTime(
      BuildContext context, SettingsProvider settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOf(settings.reminderMinutes),
      helpText: 'Remind me at',
    );
    if (picked != null) {
      await settings.setReminderTime(picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    const danger = Color(0xFFD65745);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColor.Screenbackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        icon: Icon(Icons.delete_forever_rounded, size: 30.sp, color: danger),
        title: Text('Delete account?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColor.Textcolor)),
        content: Text(
          'Your profile, progress, saved items and subscription will be '
          'removed for good. This cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13.sp, height: 1.45, color: Colors.grey.shade700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46.h,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.r)),
              ),
              child: Text('Delete my account',
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Keep my account',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    try {
      await context.read<AuthProvider>().deleteAccount();
    } catch (e) {
      // A session that had already ended is signed out by ApiClient; anything
      // else left the account in place, so say so and stay here.
      if (context.mounted) {
        showAppSnackBar(context, e.toString().replaceFirst('Exception: ', ''),
            kind: AppMessage.failure);
      }
      return;
    }
    // AuthGate swaps the root to the login screen; just get out of its way.
    navigator.popUntil((route) => route.isFirst);
  }

  static TimeOfDay _timeOf(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      appBar: AppBar(
        backgroundColor: AppColor.Screenbackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.chevron_left_rounded,
              size: 30.sp, color: Colors.black),
        ),
        title: Text('Settings',
            style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
      ),
      // Nothing rendered until the stored values are in, or every switch
      // would flick from its default to the real value a frame later.
      body: !settings.loaded
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              children: [
                const _SectionLabel('Notifications'),
                _Card(children: [
                  _SwitchRow(
                    title: 'Push notification',
                    // Firebase is set up for Android only. On a phone without
                    // it the switch is disabled and says so, rather than
                    // flipping on and delivering nothing.
                    subtitle: settings.pushAvailable
                        ? 'Get told when a new course is published'
                        : 'Not available on this device yet',
                    value: settings.pushAvailable && settings.push,
                    onChanged: settings.pushAvailable
                        ? (on) => _report(context, settings.setPush(on))
                        : null,
                  ),
                  const _RowDivider(),
                  _SwitchRow(
                    title: 'Daily study reminder',
                    subtitle: 'A reminder to study at the same time each day',
                    value: settings.dailyReminder,
                    onChanged: (on) =>
                        _report(context, settings.setDailyReminder(on)),
                  ),
                  if (settings.dailyReminder) ...[
                    const _RowDivider(),
                    _LinkRow(
                      title: 'Reminder time',
                      trailing: _timeOf(settings.reminderMinutes)
                          .format(context),
                      onTap: () => _pickReminderTime(context, settings),
                    ),
                  ],
                  const _RowDivider(),
                  _SwitchRow(
                    title: 'Sound effect',
                    subtitle: 'Play a sound for right and wrong answers',
                    value: settings.sound,
                    onChanged: (on) => settings.setSound(on),
                  ),
                ]),

                SizedBox(height: 18.h),
                const _SectionLabel('Privacy'),
                _Card(children: [
                  _SwitchRow(
                    title: 'Usage analytics',
                    subtitle: settings.analyticsAvailable
                        ? 'Share anonymous usage to help us improve the app'
                        : 'Not available on this device yet',
                    value: settings.analyticsAvailable && settings.analytics,
                    onChanged: settings.analyticsAvailable
                        ? (on) => settings.setAnalytics(on)
                        : null,
                  ),
                ]),

                SizedBox(height: 18.h),
                const _SectionLabel('Support'),
                _Card(children: [
                  _LinkRow(
                    title: 'Help & support',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                    ),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    title: 'Rate the app',
                    // No store listing yet, so this opens the FAQ rather than
                    // a dead link. Point it at the store URL on release.
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    ),
                  ),
                  const _RowDivider(),
                  // Not a link: there is nothing to open, and a chevron would
                  // say otherwise.
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 17.h, 16.w, 17.h),
                    child: Text('App version $_version',
                        style: TextStyle(
                            fontSize: 14.sp, color: Colors.grey.shade700)),
                  ),
                ]),

                // A visitor on sample content has no account to delete.
                if (!DemoMode.active) ...[
                  SizedBox(height: 18.h),
                  const _SectionLabel('Account'),
                  _Card(children: [
                    _LinkRow(
                      title: 'Delete account',
                      color: const Color(0xFFD65745),
                      onTap: () => _confirmDelete(context),
                    ),
                  ]),
                ],

                SizedBox(height: 20.h),
                // Stated, not offered: screen protection is not the student's
                // to switch off, and a disabled toggle would imply it might be.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 15.sp, color: Colors.grey.shade600),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Screenshots and screen recording are blocked on '
                          'course content. This cannot be turned off.',
                          style: TextStyle(
                              fontSize: 11.5.sp,
                              height: 1.4,
                              color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4.w, 10.h, 4.w, 10.h),
        child: Text(text,
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(children: children),
      );
}

/// A hairline between rows, inset so it does not run to the card's edge.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 16.w,
        endIndent: 16.w,
        color: Colors.grey.shade200,
      );
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;

  /// Null disables the switch — for a feature this phone cannot provide.
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 10.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
                SizedBox(height: 3.h),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12.sp,
                        height: 1.3,
                        color: Colors.grey.shade600)),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColor.buttoncolor,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String title;

  /// A value shown before the chevron — the reminder's time.
  final String? trailing;

  final VoidCallback onTap;

  final Color color;

  const _LinkRow(
      {required this.title,
      required this.onTap,
      this.trailing,
      this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 17.h, 16.w, 17.h),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColor.buttoncolor)),
              SizedBox(width: 4.w),
            ],
            Icon(Icons.chevron_right_rounded,
                size: 22.sp, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
