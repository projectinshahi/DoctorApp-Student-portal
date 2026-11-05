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
  /// The videos the preview plays.
  ///
  /// YouTube links, which the lesson screen already recognises and opens in
  /// its YouTube player — nothing is hosted and nothing is bundled, so they
  /// work on a fresh install with no backend at all.
  ///
  /// Replace these to change what a visitor watches. This list is the only
  /// place they appear.
  static const List<String> sampleVideoUrls = [
    'https://youtu.be/28CYhgjrBLA',
    'https://youtu.be/CA8r06-6yFE',
    'https://youtu.be/M6Z9bkd7zF8',
  ];

  /// Kept for the one caller that wants a single url.
  static String get sampleVideoUrl => sampleVideoUrls.first;

  /// YouTube's own still for a video, which is public and needs no key — so
  /// the list has a picture per row without anything being hosted.
  static String thumbnailFor(String url) {
    final id = Uri.parse(url).pathSegments.first;
    return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

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
                'title': 'Cardiovascular system — an overview',
                'type': 'video',
                'accessType': 'free',
                'locked': false,
                'videoUrl': sampleVideoUrls[0],
                'thumbnailUrl': thumbnailFor(sampleVideoUrls[0]),
                'lastPositionSeconds': 0,
              },
              {
                'id': -105,
                'title': 'Genetic conditions — how mutations cause them',
                'type': 'video',
                'accessType': 'free',
                'locked': false,
                'videoUrl': sampleVideoUrls[1],
                'thumbnailUrl': thumbnailFor(sampleVideoUrls[1]),
                'lastPositionSeconds': 0,
              },
              {
                'id': -106,
                'title': "Huntington's disease — genetics and symptoms",
                'type': 'video',
                'accessType': 'free',
                'locked': false,
                'videoUrl': sampleVideoUrls[2],
                'thumbnailUrl': thumbnailFor(sampleVideoUrls[2]),
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
              // Premium videos: listed with a Premium chip and no link, the
              // way the server sends a lesson a visitor has not paid for.
              // Tapping one asks them to sign in, as a locked QBank subject
              // does.
              {
                'id': -107,
                'title': 'Pulmonology — asthma and COPD',
                'type': 'video',
                'accessType': 'premium',
                'locked': true,
                'lastPositionSeconds': 0,
              },
            ],
          },
          {
            'id': -12,
            'title': 'Obstetrics and Gynaecology',
            'lessons': [
              {
                'id': -108,
                'title': 'Antenatal care — the booking visit',
                'type': 'video',
                'accessType': 'premium',
                'locked': true,
                'lastPositionSeconds': 0,
              },
              {
                'id': -109,
                'title': 'Obstetric emergencies — postpartum haemorrhage',
                'type': 'video',
                'accessType': 'premium',
                'locked': true,
                'lastPositionSeconds': 0,
              },
              {
                'id': -104,
                'title': 'Antenatal care — question bank',
                'type': 'quiz',
                'accessType': 'premium',
                'locked': true,
                'questionCount': 28,
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

  /// `/users/me/rapid-recalls`
  ///
  /// Filed under the AI video lessons, one topic per video. Free decks open;
  /// premium ones are listed locked with their cover, and a visitor who taps
  /// one is asked to sign in. Like the server, the list carries each deck's
  /// first image and its card count, not its cards.
  static Map<String, dynamic> get rapidRecalls => {
        'rapidRecalls': [
          for (final deck in _recallDecks)
            {
              ...deck,
              'cardCount': (deck['cards'] as List).length,
              'coverImageUrl': (deck['cards'] as List).first['imageUrl'],
            }..remove('cards'),
        ],
      };

  /// `/users/me/rapid-recalls/:id`, or null for a deck not in the sample.
  static Map<String, dynamic>? rapidRecallDeck(int id) {
    for (final deck in _recallDecks) {
      if (deck['id'] == id) return {'rapidRecall': deck};
    }
    return null;
  }

  static const _medicine = {'id': -11, 'title': 'Internal Medicine'};

  /// A still from inside one of [sampleVideoUrls]. YouTube serves four per
  /// video: `maxresdefault` and three frames through it, `sd1`–`sd3`.
  static String _frame(int video, String name) {
    final id = Uri.parse(sampleVideoUrls[video]).pathSegments.first;
    return 'https://img.youtube.com/vi/$id/$name.jpg';
  }

  /// One free deck per AI video, filed under that video's lesson and drawn
  /// from its frames, so a visitor can watch a lesson and then revise it.
  /// Notes use `## ` for a heading and `• ` for a point; the cards screen
  /// lays those out.
  static List<Map<String, dynamic>> get _recallDecks => [
        {
          'id': -301,
          'title': 'Cardiovascular system — the essentials',
          'chapterId': -11,
          'chapter': _medicine,
          'lesson': {
            'id': -101,
            'title': 'Cardiovascular system — an overview',
          },
          'displayOrder': 1,
          'accessType': 'free',
          'locked': false,
          'cards': [
            _card(-3011, _frame(0, 'maxresdefault'), '''
## Two circuits in one loop
The cardiovascular system is the heart, the blood vessels and the blood — a closed loop with two circuits in series.
• Pulmonary circulation: right ventricle → pulmonary artery → lungs → pulmonary veins → left atrium. Blood unloads CO₂ and picks up oxygen.
• Systemic circulation: left ventricle → aorta → every tissue → venae cavae → right atrium.
• Exam favourite: the pulmonary artery is the only artery carrying deoxygenated blood, and the pulmonary veins the only veins carrying oxygenated blood.'''),
            _card(-3012, _frame(0, 'sd1'), '''
## The four chambers and their valves
• Right atrium: receives venous blood from the superior and inferior venae cavae and the coronary sinus.
• Right ventricle: pumps through the pulmonary valve into the pulmonary trunk, at low pressure.
• Left atrium: receives oxygenated blood from the four pulmonary veins.
• Left ventricle: the thickest wall, pumping through the aortic valve into the aorta at systemic pressure.
• Heart sounds: S1 is the mitral and tricuspid valves closing; S2 is the aortic and pulmonary valves closing.'''),
            _card(-3013, _frame(0, 'sd2'), '''
## What the blood carries
• Gases: oxygen bound to haemoglobin from the lungs; CO₂ back to them, mostly as bicarbonate.
• Nutrients: absorbed from the gut and carried by the portal vein to the liver before anywhere else.
• Wastes: urea and creatinine, filtered by the kidneys, which receive about 20–25% of cardiac output through the renal arteries.
• Also hormones, heat and immune cells — the circulation is the body's delivery network.'''),
            _card(-3014, _frame(0, 'sd3'), '''
## Vessels, in the order blood meets them
Aorta → arteries → arterioles → capillaries → venules → veins → venae cavae.
• Arterioles are the resistance vessels: they set blood pressure and decide where flow goes.
• Capillaries are one cell thick — the only place where exchange with the tissues happens.
• Veins are capacitance vessels, holding about two-thirds of the blood volume at rest.
• Remember: cardiac output = heart rate × stroke volume, about 5 L/min at rest.'''),
          ],
        },
        {
          'id': -302,
          'title': 'Genetic conditions — mutations and inheritance',
          'chapterId': -11,
          'chapter': _medicine,
          'lesson': {
            'id': -105,
            'title': 'Genetic conditions — how mutations cause them',
          },
          'displayOrder': 2,
          'accessType': 'free',
          'locked': false,
          'cards': [
            _card(-3021, _frame(1, 'maxresdefault'), '''
## What causes a genetic condition
A change in DNA — a mutation, or variant — alters the instructions in a gene, so the protein it codes for is missing, reduced or works abnormally.
• Germline variants are present in every cell and can be inherited.
• Somatic variants arise after conception, in one tissue only — most cancers — and are not passed on.
• Not every variant causes disease: many are harmless differences between people.'''),
            _card(-3022, _frame(1, 'sd1'), '''
## Cells, chromosomes and genes
• The body is made of trillions of cells, and nearly every one carries the whole genome in its nucleus.
• Humans have 46 chromosomes: 22 pairs of autosomes and one pair of sex chromosomes, XX or XY.
• Around 20,000 protein-coding genes, one copy from each parent.
• Mitochondria carry their own small DNA, inherited from the mother only.'''),
            _card(-3023, _frame(1, 'sd2'), '''
## Types of mutation
• Point mutation — one base changed. Missense gives a new amino acid (sickle cell), nonsense a premature stop codon, silent no change.
• Insertion or deletion — a frameshift when it is not a multiple of three bases (many cases of Duchenne).
• Chromosomal — an extra or missing chromosome (trisomy 21), or extra or missing DNA that affects several genes in the region.
• Repeat expansion — a repeated triplet grows longer (Huntington's, fragile X).'''),
            _card(-3024, _frame(1, 'sd3'), '''
## How they are passed down
• Autosomal dominant: one copy is enough, so each child of an affected parent has a 50% risk. Huntington's, Marfan, adult polycystic kidney disease.
• Autosomal recessive: two copies are needed; two carrier parents have a 25% risk with each child. Cystic fibrosis, sickle cell, thalassaemia.
• X-linked recessive: mostly affects males; a carrier mother passes it to half her sons. Haemophilia A, Duchenne.
• Mitochondrial: from the mother to all of her children, never from the father.'''),
          ],
        },
        {
          'id': -305,
          'title': "Huntington's disease — rapid review",
          'chapterId': -11,
          'chapter': _medicine,
          'lesson': {
            'id': -106,
            'title': "Huntington's disease — genetics and symptoms",
          },
          'displayOrder': 3,
          'accessType': 'free',
          'locked': false,
          'cards': [
            _card(-3051, _frame(2, 'maxresdefault'), '''
## Huntington's disease at a glance
An autosomal dominant neurodegenerative disease caused by a CAG triplet repeat expansion in the HTT (huntingtin) gene on chromosome 4.
• Normal gene: 10–35 CAG repeats. Disease: 36 or more — 36–39 with reduced penetrance, 40 or more fully penetrant.
• Each CAG adds a glutamine, and the long polyglutamine huntingtin is toxic to neurons.
• Classic triad: chorea, cognitive decline and psychiatric symptoms.'''),
            _card(-3052, _frame(2, 'sd1'), '''
## Where the damage is
• The striatum — caudate nucleus and putamen — is hit first, losing its GABA-releasing medium spiny neurons.
• On CT or MRI the caudate shrinks, so the lateral ventricles look enlarged, described as "boxcar" ventricles.
• Chemistry: GABA and acetylcholine fall while dopamine is relatively high — why dopamine-depleting drugs ease the chorea.'''),
            _card(-3053, _frame(2, 'sd2'), '''
## Inheritance and anticipation
• Autosomal dominant: each child of an affected parent has a 50% chance of inheriting it.
• Anticipation: the repeat tends to lengthen in the next generation, so the disease starts earlier and is more severe.
• Expansion is greatest when passed through the father. The juvenile (Westphal) form, rigid rather than choreic, usually has more than 60 repeats.
• Typical onset 30–50 years. Diagnosis is a genetic test of the repeat length.'''),
            _card(-3054, _frame(2, 'sd3'), '''
## Treatment and complications
• No cure. Chorea: tetrabenazine or deutetrabenazine (VMAT2 inhibitors); antipsychotics also help.
• Depression and irritability: SSRIs, with regular screening for suicide risk.
• Life-threatening complications: pulmonary aspiration and pneumonia — the commonest cause of death — heart disease, falls and suicide.
• Survival is about 15–20 years from onset.'''),
          ],
        },
        // Premium: one deeper deck per video, listed with its cover so a
        // visitor sees what a plan opens.
        _premiumDeck(-303, 'Heart sounds and murmurs — exam drill',
            lessonId: -101,
            lessonTitle: 'Cardiovascular system — an overview',
            video: 0,
            cards: 6),
        _premiumDeck(-304, 'Inheritance patterns — case questions',
            lessonId: -105,
            lessonTitle: 'Genetic conditions — how mutations cause them',
            video: 1,
            cards: 5),
        _premiumDeck(-306, "Huntington's disease — clinical scenarios",
            lessonId: -106,
            lessonTitle: "Huntington's disease — genetics and symptoms",
            video: 2,
            cards: 5),
      ];

  static Map<String, dynamic> _premiumDeck(
    int id,
    String title, {
    required int lessonId,
    required String lessonTitle,
    required int video,
    required int cards,
  }) =>
      {
        'id': id,
        'title': title,
        'chapterId': -11,
        'chapter': _medicine,
        'lesson': {'id': lessonId, 'title': lessonTitle},
        'displayOrder': 10,
        'accessType': 'premium',
        'locked': true,
        // Never served to a visitor; here for the count and the cover.
        'cards': [
          for (var i = 0; i < cards; i++)
            _card(id * 10 - i, i == 0 ? _frame(video, 'hq3') : null,
                'Premium'),
        ],
      };

  static Map<String, dynamic> _card(int id, String? image, String note) =>
      {'id': id, 'imageUrl': image, 'note': note.trim()};

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
