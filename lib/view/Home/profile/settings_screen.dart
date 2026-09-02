// lib/view/Home/profile/settings_screen.dart
//
// Settings that actually do something.
//
// Only preferences the app can honour on its own are here. Anything needing
// a server — push notifications, email preferences, account deletion — is
// left out rather than shipped as a switch that flips and changes nothing,
// which is worse than no switch at all.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theam /app_color.dart';

/// Keys are namespaced so a later feature cannot collide with them.
class SettingsKeys {
  static const autoplayNext = 'settings.autoplayNext';
  static const defaultSpeed = 'settings.defaultSpeed';
  static const dataSaver = 'settings.dataSaver';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SharedPreferences? _prefs;

  bool _autoplayNext = false;
  bool _dataSaver = false;
  double _defaultSpeed = 1.0;

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
      _autoplayNext = prefs.getBool(SettingsKeys.autoplayNext) ?? false;
      _dataSaver = prefs.getBool(SettingsKeys.dataSaver) ?? false;
      _defaultSpeed = prefs.getDouble(SettingsKeys.defaultSpeed) ?? 1.0;
    });
  }

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
        title: Text('Settings',
            style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
      ),
      // Nothing rendered until the stored values are in, or the switches
      // would flick from their defaults to the real values a frame later.
      body: _prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
              children: [
                _SectionLabel('Playback'),
                _Card(children: [
                  SwitchListTile(
                    value: _autoplayNext,
                    activeThumbColor: AppColor.buttoncolor,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w),
                    title: Text('Autoplay next lesson',
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text('Start the following video when one ends',
                        style: TextStyle(
                            fontSize: 11.5.sp, color: Colors.grey.shade600)),
                    onChanged: (on) {
                      setState(() => _autoplayNext = on);
                      _prefs!.setBool(SettingsKeys.autoplayNext, on);
                    },
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 6.h),
                    child: Row(
                      children: [
                        Text('Default speed',
                            style: TextStyle(
                                fontSize: 14.sp, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${_defaultSpeed}x',
                            style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColor.buttoncolor)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 8.h),
                    child: Wrap(
                      spacing: 8.w,
                      children: [
                        for (final speed in const [0.75, 1.0, 1.25, 1.5, 2.0])
                          ChoiceChip(
                            label: Text('${speed}x',
                                style: TextStyle(fontSize: 12.sp)),
                            selected: _defaultSpeed == speed,
                            selectedColor:
                                AppColor.buttoncolor.withValues(alpha: 0.2),
                            onSelected: (_) {
                              setState(() => _defaultSpeed = speed);
                              _prefs!
                                  .setDouble(SettingsKeys.defaultSpeed, speed);
                            },
                          ),
                      ],
                    ),
                  ),
                ]),
                SizedBox(height: 18.h),
                _SectionLabel('Data'),
                _Card(children: [
                  SwitchListTile(
                    value: _dataSaver,
                    activeThumbColor: AppColor.buttoncolor,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w),
                    title: Text('Data saver',
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    subtitle: Text('Ask before playing on mobile data',
                        style: TextStyle(
                            fontSize: 11.5.sp, color: Colors.grey.shade600)),
                    onChanged: (on) {
                      setState(() => _dataSaver = on);
                      _prefs!.setBool(SettingsKeys.dataSaver, on);
                    },
                  ),
                ]),
                SizedBox(height: 18.h),
                _SectionLabel('Security'),
                _Card(children: [
                  ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w),
                    leading: Icon(Icons.screenshot_monitor_outlined,
                        size: 20.sp, color: AppColor.buttoncolor),
                    title: Text('Screen protection',
                        style: TextStyle(
                            fontSize: 14.sp, fontWeight: FontWeight.w600)),
                    // Stated, not offered: it is not the student's to switch
                    // off, and a disabled toggle would imply it might be.
                    subtitle: Text(
                        'Screenshots and screen recording are blocked on '
                        'course content. This cannot be turned off.',
                        style: TextStyle(
                            fontSize: 11.5.sp,
                            height: 1.35,
                            color: Colors.grey.shade600)),
                  ),
                ]),
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
        padding: EdgeInsets.fromLTRB(4.w, 10.h, 4.w, 8.h),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.grey.shade600)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(children: children),
      );
}
