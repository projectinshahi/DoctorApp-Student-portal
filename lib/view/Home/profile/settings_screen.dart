// lib/view/Home/profile/settings_screen.dart
//
// Notifications, Privacy and Support.
//
// Every switch here persists, so a student's choice survives a restart and
// any feature can read it. Three of them do not yet change anything, and the
// note above each row says what it still needs — a switch that flips and
// silently does nothing is worse than no switch at all, and the next person
// should not have to guess which is which.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theam /app_color.dart';
import 'info_screens.dart';

/// Keys are namespaced so a later feature cannot collide with them.
class SettingsKeys {
  static const pushNotifications = 'settings.pushNotifications';
  static const dailyReminder = 'settings.dailyReminder';
  static const soundEffects = 'settings.soundEffects';
  static const usageAnalytics = 'settings.usageAnalytics';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;

  bool _push = false;
  bool _reminder = false;
  bool _sound = false;
  bool _analytics = false;

  /// Must match `version:` in pubspec.yaml.
  static const String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _push = prefs.getBool(SettingsKeys.pushNotifications) ?? false;
      _reminder = prefs.getBool(SettingsKeys.dailyReminder) ?? false;
      _sound = prefs.getBool(SettingsKeys.soundEffects) ?? false;
      _analytics = prefs.getBool(SettingsKeys.usageAnalytics) ?? false;
    });
  }

  void _set(String key, bool value, void Function(bool) apply) {
    setState(() => apply(value));
    _prefs?.setBool(key, value);
  }

  void _open(Widget screen) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );

  @override
  Widget build(BuildContext context) {
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
      body: _prefs == null
          ? const SizedBox.shrink()
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              children: [
                const _SectionLabel('Notifications'),
                _Card(children: [
                  // Needs a push service — FCM on Android, APNs on iOS — and
                  // the device token registered with the backend. Until then
                  // this records the choice and nothing sends anything.
                  _SwitchRow(
                    title: 'Push notification',
                    subtitle: 'Receive alerts and updates',
                    value: _push,
                    onChanged: (on) => _set(
                        SettingsKeys.pushNotifications, on, (v) => _push = v),
                  ),
                  const _RowDivider(),
                  // The closest to working: a local notification needs no
                  // server at all, only flutter_local_notifications and a
                  // scheduled time.
                  _SwitchRow(
                    title: 'Daily study reminder',
                    subtitle: 'Get reminded to study every day',
                    value: _reminder,
                    onChanged: (on) => _set(
                        SettingsKeys.dailyReminder, on, (v) => _reminder = v),
                  ),
                  const _RowDivider(),
                  // The quiz plays no sounds today. When it does, it reads
                  // this key before playing one.
                  _SwitchRow(
                    title: 'Sound effect',
                    subtitle: 'Play sound during quizzes',
                    value: _sound,
                    onChanged: (on) =>
                        _set(SettingsKeys.soundEffects, on, (v) => _sound = v),
                  ),
                ]),

                SizedBox(height: 18.h),
                const _SectionLabel('Privacy'),
                _Card(children: [
                  // Off by default, deliberately: analytics a student has not
                  // agreed to is the wrong default — and there is no
                  // analytics SDK in the app to honour it either way.
                  _SwitchRow(
                    title: 'Usage analytics',
                    subtitle: 'Help us improve the app',
                    value: _analytics,
                    onChanged: (on) => _set(
                        SettingsKeys.usageAnalytics, on, (v) => _analytics = v),
                  ),
                ]),

                SizedBox(height: 18.h),
                const _SectionLabel('Support'),
                _Card(children: [
                  _LinkRow(
                    title: 'Help & support',
                    onTap: () => _open(const ContactUsScreen()),
                  ),
                  const _RowDivider(),
                  _LinkRow(
                    title: 'Rate the app',
                    // No store listing yet, so this opens the FAQ rather than
                    // a dead link. Point it at the store URL on release.
                    onTap: () => _open(const FaqScreen()),
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
  final ValueChanged<bool> onChanged;

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
  final VoidCallback onTap;

  const _LinkRow({required this.title, required this.onTap});

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
                      color: Colors.black87)),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 22.sp, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
