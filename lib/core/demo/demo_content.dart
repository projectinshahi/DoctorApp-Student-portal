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
                // Premium until there is a real video to play. A free lesson
                // whose url goes nowhere is worse than a padlock: it reads as
                // a broken player rather than as something to buy.
                'accessType': 'premium',
                'locked': true,
                'durationMinutes': 12,
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

  /// `/users/me/profile`
  ///
  /// A visitor still opens the drawer — it is where the app explains itself,
  /// with the terms, the FAQ and the way to contact anyone. The account half
  /// of it asks them to sign in instead of pretending there is somebody
  /// signed in.
  static Map<String, dynamic> get profile => {
        'id': -1,
        'name': 'Guest',
        'email': 'Not signed in',
        'role': 'student',
        'status': 'verified',
        'selectedCourse': {
          'id': -1,
          'title': 'Sample exam',
          'accessType': 'premium',
        },
        'subscriptionInfo': {'isPremiumCourse': true, 'hasPaid': true},
      };

  /// `POST /users/me/lessons/:id/quiz-attempts`
  ///
  /// The free subject's questions. Each carries `correctOptionId` and its
  /// explanation, so the quiz screen reveals the verdict from the device —
  /// the same path it already uses when the server ships the key.
  static Map<String, dynamic> get quiz => {
        'attemptId': -2,
        'resumed': false,
        'completed': false,
        'lessonId': -102,
        'quiz': {'id': -2, 'title': 'Cardiology — rapid MCQs'},
        'totalQuestions': 3,
        'totalMarks': 3,
        'answered': const [],
        'questions': [
          {
            'id': -401,
            'questionText':
                'A 65-year-old has crushing central chest pain with ST '
                    'elevation in leads II, III and aVF. Which artery is most '
                    'likely occluded?',
            'difficulty': 'medium',
            'marksCorrect': 1,
            'marksIncorrect': 0,
            'correctOptionId': -502,
            'explanation':
                'II, III and aVF are the inferior leads, supplied by the '
                    'right coronary artery in about 80% of people.',
            'options': [
              {'id': -501, 'optionText': 'Left anterior descending', 'displayOrder': 1},
              {'id': -502, 'optionText': 'Right coronary artery', 'displayOrder': 2},
              {'id': -503, 'optionText': 'Left circumflex', 'displayOrder': 3},
              {'id': -504, 'optionText': 'Left main stem', 'displayOrder': 4},
            ],
          },
          {
            'id': -402,
            'questionText':
                'Which murmur is best heard at the apex and radiates to the '
                    'axilla?',
            'difficulty': 'easy',
            'marksCorrect': 1,
            'marksIncorrect': 0,
            'correctOptionId': -512,
            'explanation':
                'Mitral regurgitation is a pansystolic murmur at the apex '
                    'radiating to the axilla.',
            'options': [
              {'id': -511, 'optionText': 'Aortic stenosis', 'displayOrder': 1},
              {'id': -512, 'optionText': 'Mitral regurgitation', 'displayOrder': 2},
              {'id': -513, 'optionText': 'Pulmonary stenosis', 'displayOrder': 3},
              {'id': -514, 'optionText': 'Tricuspid stenosis', 'displayOrder': 4},
            ],
          },
          {
            'id': -403,
            'questionText':
                'First-line treatment for a stable patient in new atrial '
                    'fibrillation with a fast ventricular rate?',
            'difficulty': 'medium',
            'marksCorrect': 1,
            'marksIncorrect': 0,
            'correctOptionId': -521,
            'explanation':
                'Rate control with a beta blocker comes first in a stable '
                    'patient. Cardioversion is for haemodynamic instability.',
            'options': [
              {'id': -521, 'optionText': 'Beta blocker', 'displayOrder': 1},
              {'id': -522, 'optionText': 'Immediate DC cardioversion', 'displayOrder': 2},
              {'id': -523, 'optionText': 'IV adenosine', 'displayOrder': 3},
              {'id': -524, 'optionText': 'IV magnesium', 'displayOrder': 4},
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
            'marksIncorrect': -0.25,
            // The key ships with the question here, which it never does from
            // the server — a student could read every answer out of the
            // response. In the preview there is no server to ask and nothing
            // to protect: the point is that a visitor can actually answer.
            'explanation': 'Sudden one-sided weakness with facial droop and '
                'slurred speech is the classic FAST triad. Treat as a stroke '
                'until proven otherwise — time is brain.',
            'options': [
              {
                'id': -301,
                'optionText': 'Acute stroke',
                'displayOrder': 1,
                'isCorrect': true
              },
              {
                'id': -302,
                'optionText': 'Migraine',
                'displayOrder': 2,
                'isCorrect': false
              },
              {
                'id': -303,
                'optionText': "Bell's palsy alone",
                'displayOrder': 3,
                'isCorrect': false
              },
              {
                'id': -304,
                'optionText': 'Cluster headache',
                'displayOrder': 4,
                'isCorrect': false
              },
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
