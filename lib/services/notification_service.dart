// lib/services/notification_service.dart
//
// Everything that reaches the notification shade.
//
// Three sources, one plugin to show them:
//  * course announcements, pushed to the Firebase topic every app subscribes
//    to (the backend's push.service.js),
//  * notifications for one student — a course they were added to — pushed to
//    this phone's FCM token, which is sent to the backend after sign-in, and
//  * the daily study reminder, scheduled on the phone itself, no server.
//
// Split in two on purpose. [init] runs at app start, before anyone is signed
// in: the notification that launched the app can only be caught then.
// [registerToken] runs once a student is signed in, because the backend files
// the token under their id.
//
// Push needs Firebase, which is configured for Android only — the iOS app has
// no GoogleService-Info.plist. [pushAvailable] says which, so nothing here
// throws on a phone where push cannot work.
import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/constant/api_constant.dart';
import 'refresh_api_services.dart';

class NotificationService {
  NotificationService();

  static final NotificationService instance = NotificationService();

  /// The backend sends every course announcement to this one topic.
  static const String topic = 'all-students';

  /// `data.type` values a notification carries.
  static const String newCourseType = 'new_course';
  static const String courseJoinType = 'course_join';
  static const String reminderType = 'study_reminder';

  /// Fixed, so scheduling again replaces the reminder rather than adding one.
  static const int reminderId = 7001;

  /// Where the backend files this phone's token. No student id: the server
  /// takes the student from the access token, so a phone cannot be registered
  /// against someone else's account.
  static String get tokenUrl => '${ApiConstant.baseUrl}/users/me/fcm-token';

  /// Must match the backend's channelId exactly.
  static const AndroidNotificationChannel newCoursesChannel =
      AndroidNotificationChannel(
    'new_courses',
    'New courses',
    description: 'When a new course is published',
    importance: Importance.high,
  );

  /// Notifications about this student's own courses — course_join and
  /// anything else sent to their token rather than to everyone.
  static const AndroidNotificationChannel courseUpdatesChannel =
      AndroidNotificationChannel(
    'course_updates',
    'Course updates',
    description: 'Changes to the courses you are enrolled in',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel reminderChannel =
      AndroidNotificationChannel(
    'study_reminder',
    'Study reminder',
    description: 'Your daily reminder to study',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Set by AuthGate, which knows whether anyone is signed in to open
  /// anything for. Receives the notification's data map. A tap arriving
  /// before it is set waits in [pendingOpen].
  void Function(Map<String, dynamic> data)? onOpen;

  /// A push that arrived while the app was open. The backend has already
  /// stored it, so this only has to move the badge.
  void Function(Map<String, dynamic> data)? onReceived;

  /// A tap that arrived before [onOpen] existed — usually the notification
  /// that launched the app.
  Map<String, dynamic>? pendingOpen;

  Map<String, dynamic>? takePendingOpen() {
    final pending = pendingOpen;
    pendingOpen = null;
    return pending;
  }

  /// The student the token was last sent for. Read at the moment FCM rotates
  /// the token, so a refresh after a sign-out sends nothing.
  int? _studentId;

  /// One listener for the whole app run — it outlives sign-ins.
  StreamSubscription<String>? _tokenRefresh;

  bool get pushAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Channels, the time zone and the push listeners. Called once from
  /// main(), before runApp, so a notification that launched the app is not
  /// lost.
  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Asked for after sign-in — never at launch, where a prompt with no
          // context gets refused.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _dispatch(decodePayload(response.payload)),
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(newCoursesChannel);
      await android?.createNotificationChannel(courseUpdatesChannel);
      await android?.createNotificationChannel(reminderChannel);

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        pendingOpen = decodePayload(launch!.notificationResponse?.payload);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('NOTIFICATIONS  not initialised: $error');
    }

    await _initTimeZone();
    if (pushAvailable) await _initPush();
  }

  Future<void> _initTimeZone() async {
    try {
      tz_data.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (error) {
      // Stays on UTC: the reminder still comes daily, just at an offset hour.
      if (kDebugMode) debugPrint('NOTIFICATIONS  time zone unknown: $error');
    }
  }

  Future<void> _initPush() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

      // App open: Android shows nothing by itself, so the notification is
      // put in the shade by hand.
      FirebaseMessaging.onMessage.listen(_showInForeground);

      // App in the background, notification tapped.
      FirebaseMessaging.onMessageOpenedApp
          .listen((message) => _dispatch(dataOf(message)));

      // App closed, notification tapped: it launched the app.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) pendingOpen = dataOf(initial);
    } catch (error) {
      if (kDebugMode) debugPrint('PUSH  not initialised: $error');
    }
  }

  void _showInForeground(RemoteMessage message) {
    onReceived?.call(dataOf(message));

    final shown = message.notification;
    if (shown == null) return;

    final channel = message.data['type'] == newCourseType
        ? newCoursesChannel
        : courseUpdatesChannel;

    _plugin.show(
      id: message.hashCode,
      title: shown.title,
      body: shown.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // The whole data map, so a tap on this copy routes exactly like a tap
      // on the system's — course id included.
      payload: jsonEncode(dataOf(message)),
    );
  }

  /// A message's data plus the words it was shown with, so the app can put
  /// a tapped notification on screen without fetching anything.
  @visibleForTesting
  static Map<String, dynamic> dataOf(RemoteMessage message) {
    final shown = message.notification;
    return {
      ...message.data,
      if (shown?.title != null) 'title': shown!.title,
      if (shown?.body != null) 'body': shown!.body,
    };
  }

  void _dispatch(Map<String, dynamic>? data) {
    if (data == null) return;
    final handler = onOpen;
    if (handler == null) {
      pendingOpen = data;
    } else {
      handler(data);
    }
  }

  /// A local notification's payload, back into its data map.
  ///
  /// A plain string is read as a bare type: that is the shape payloads had
  /// before they carried a course id, so a reminder scheduled by an earlier
  /// build still opens.
  @visibleForTesting
  static Map<String, dynamic>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Not JSON — a plain type string.
    }
    return {'type': payload};
  }

  /// FCM allows only strings in `data`, so the id arrives as "22".
  static int? courseIdFrom(Map<String, dynamic> data) {
    final raw = data['courseId'];
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  /// Asks to show notifications. True when allowed.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        // Null below Android 13, where there is no permission to ask for.
        return await android.requestNotificationsPermission() ?? true;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(
                alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (error) {
      if (kDebugMode) debugPrint('NOTIFICATIONS  permission failed: $error');
    }
    return false;
  }

  Future<void> subscribePush() async {
    if (!pushAvailable) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (error) {
      if (kDebugMode) debugPrint('PUSH  subscribe failed: $error');
    }
  }

  Future<void> unsubscribePush() async {
    if (!pushAvailable) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (error) {
      if (kDebugMode) debugPrint('PUSH  unsubscribe failed: $error');
    }
  }

  /// Sends this phone's FCM token to the backend for [studentId], and again
  /// every time FCM rotates it.
  Future<void> registerToken(int studentId) async {
    if (!pushAvailable) return;
    _studentId = studentId;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(studentId, token);
    } catch (error) {
      if (kDebugMode) debugPrint('PUSH  no token: $error');
    }

    _tokenRefresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      final id = _studentId;
      if (id != null) _sendToken(id, token);
    });
  }

  Future<void> _sendToken(int studentId, String token) async {
    try {
      // Through ApiClient, so the student's access token goes with it and an
      // expired one is refreshed on the way.
      final response = await ApiClient.post(tokenUrl, body: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      if (kDebugMode) {
        debugPrint('PUSH  token sent for student $studentId: '
            'HTTP ${response.statusCode}');
      }
    } catch (error) {
      // Sent again on the next session, or on the next rotation.
      if (kDebugMode) debugPrint('PUSH  token not sent: $error');
    }
  }

  /// Stops notifications aimed at the student who is leaving.
  ///
  /// Deleting the token, not just forgetting it: the backend still holds it
  /// against their account, and the next student to sign in on this phone
  /// would otherwise receive their notifications. A fresh token is issued for
  /// the next sign-in.
  Future<void> unregisterToken() async {
    _studentId = null;
    if (!pushAvailable) return;

    try {
      // Server first: after deleteToken() the value is gone, and the row would
      // be left behind against the student who just signed out.
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // In the query string because ApiClient.delete sends no body.
        await ApiClient.delete('$tokenUrl?token=${Uri.encodeComponent(token)}');
      }
    } catch (error) {
      // Not fatal: the backend drops tokens that FCM reports as unregistered.
      if (kDebugMode) debugPrint('PUSH  server token not removed: $error');
    }

    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      if (kDebugMode) debugPrint('PUSH  token not deleted: $error');
    }
  }

  /// Schedules the reminder for [minutesOfDay] every day, replacing any
  /// earlier one.
  Future<void> scheduleDailyReminder(int minutesOfDay) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day,
          minutesOfDay ~/ 60, minutesOfDay % 60);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        id: reminderId,
        scheduledDate: at,
        title: "Time for today's revision",
        body: 'A few minutes now keeps your preparation moving.',
        payload: jsonEncode({'type': reminderType}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            reminderChannel.id,
            reminderChannel.name,
            channelDescription: reminderChannel.description,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Inexact needs no exact-alarm permission, and a reminder a few
        // minutes late is still a reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Repeats at this time of day, every day.
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('NOTIFICATIONS  reminder failed: $error');
    }
  }

  Future<void> cancelDailyReminder() async {
    try {
      await _plugin.cancel(id: reminderId);
    } catch (error) {
      if (kDebugMode) debugPrint('NOTIFICATIONS  cancel failed: $error');
    }
  }
}

/// Top level and an entry point: Android runs it in its own isolate when a
/// message arrives with the app closed, and the system shows the alert.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}
