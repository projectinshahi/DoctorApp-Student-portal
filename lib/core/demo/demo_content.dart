// lib/core/demo/demo_content.dart
//
// What the app shows before anyone signs in.
//
// The same screens as a signed-in student, fed from here instead of the
// server — there is no public content endpoint, so a visitor would otherwise
// be looking at a login form or an empty shelf.
//
// Written in the shapes the API returns, so the models parse it exactly as
// they parse a real response and no screen needs to know which it is reading.
// Small on purpose: enough to show what the app does, not enough to pass for
// the course itself. Every screen that shows it says it is a preview.
import 'package:flutter/foundation.dart';

/// Whether the app is running on sample content.
///
/// A flag rather than a provider because the services read it too, and the
/// point is to make no request at all — not to make one and ignore it.
class DemoMode {
  static bool active = false;

  @visibleForTesting
  static void reset() => active = false;
}

class DemoContent {
  /// `/users/me/selection/content`
  static Map<String, dynamic> get courseTree => {
        'course': {
          'id': -1,
          'title': 'GP Gulf Licensing Exam',
          'accessType': 'premium',
        },
        'courseType': {'id': -1, 'title': 'Sample exam'},
        'hasPaid': true,
        'progress': {'completedLessons': 1, 'totalLessons': 4},
        'chapters': [
          {
            'id': -11,
            'title': 'Internal Medicine',
            'lessons': [
              {
                'id': -101,
                'title': 'Cardiology — ECG essentials',
                'type': 'video',
                'accessType': 'free',
                'locked': false,
                'videoUrl': 'https://example.invalid/sample.mp4',
                'durationMinutes': 12,
                'lastPositionSeconds': 0,
              },
              {
                'id': -102,
                'title': 'Cardiology — rapid MCQs',
                'type': 'quiz',
                'accessType': 'free',
                'locked': false,
                'questionCount': 20,
              },
              {
                'id': -103,
                'title': 'Pulmonology — obstructive disease',
                'type': 'quiz',
                'accessType': 'premium',
                'locked': true,
                'questionCount': 35,
              },
            ],
          },
          {
            'id': -12,
            'title': 'Obstetrics and Gynaecology',
            'lessons': [
              {
                'id': -104,
                'title': 'Antenatal care',
                'type': 'video',
                'accessType': 'premium',
                'locked': true,
                'durationMinutes': 18,
              },
            ],
          },
        ],
      };

  /// `/users/me/home`
  static Map<String, dynamic> get homeSummary => {
        'modules': {
          'dailyQuiz': {
            'date': _today,
            'state': 'not_started',
            'totalQuestions': 10,
            'answeredCount': 0,
            'currentStreak': 0,
          },
        },
        'continueWatching': const [],
      };

  /// `/users/me/courses/:id/daily-quiz`
  ///
  /// One question, answerable, with its explanation — the whole point of the
  /// preview is that somebody can try the thing rather than read about it.
  static Map<String, dynamic> get dailyQuiz => {
        'available': true,
        'date': _today,
        'attemptId': -1,
        'totalQuestions': 10,
        'answeredCount': 0,
        'remainingCount': 10,
        'completed': false,
        'currentStreak': 0,
        'questions': [
          {
            'id': -201,
            'questionText':
                'Sudden onset facial droop, slurred speech and one-sided arm '
                    'weakness most suggests?',
            'difficulty': 'easy',
            'marksCorrect': 1,
            'options': [
              {'id': -301, 'optionText': 'Acute stroke', 'displayOrder': 1},
              {'id': -302, 'optionText': 'Migraine', 'displayOrder': 2},
              {
                'id': -303,
                'optionText': "Bell's palsy alone",
                'displayOrder': 3
              },
              {'id': -304, 'optionText': 'Cluster headache', 'displayOrder': 4},
            ],
          },
        ],
      };

  static String get _today {
    final now = DateTime.now();
    return '${now.year}-${_two(now.month)}-${_two(now.day)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
