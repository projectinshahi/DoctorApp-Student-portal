import 'package:dr_app/models/quiz_model.dart'
    show QuizErrorKind, QuizException;
import 'package:dr_app/models/rapid_recall_model.dart';
import 'package:dr_app/repository/plan_access_provider.dart';
import 'package:dr_app/repository/rapid_recall_provider.dart';
import 'package:dr_app/services/rapid_recall_service.dart';
import 'package:dr_app/view/Home/recall/recall_cards_screen.dart';
import 'package:dr_app/view/Home/recall/recall_decks_screen.dart';
import 'package:dr_app/view/Home/recall/recall_lists_screen.dart';
import 'package:dr_app/widget/app_bottom_nav.dart';
import 'package:dr_app/widget/loading_wave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One deck per row of the real hierarchy: two lessons under Medicine, one
/// under OBG, and one deck filed against nothing at all. A deck can also be
/// filed under a chapter with no lesson — see the chapter-level group below.
Map<String, dynamic> _deck(
  int id,
  String title, {
  int? lessonId,
  String? lessonTitle,
  int? chapterId,
  String? chapterTitle,
  String? subject,
  int cards = 1,
  String? noteUrl,
}) =>
    {
      'id': id,
      'title': title,
      'description': 'Read these the night before.',
      'noteUrl': noteUrl,
      'noteFileType': noteUrl == null ? null : 'pdf',
      'chapterId': chapterId,
      'chapter':
          chapterId == null ? null : {'id': chapterId, 'title': chapterTitle},
      'lessonId': lessonId,
      'displayOrder': 0,
      'subject': subject == null ? null : {'id': 8, 'name': subject},
      'lesson': lessonId == null
          ? null
          : {
              'id': lessonId,
              'title': lessonTitle,
              'chapter': chapterId == null
                  ? null
                  : {'id': chapterId, 'title': chapterTitle},
            },
      'cardCount': cards,
    };

final Map<String, dynamic> _listResponse = {
  'rapidRecalls': [
    _deck(1, 'ECG rapid recall',
        lessonId: 10,
        lessonTitle: 'Cardiology',
        chapterId: 100,
        chapterTitle: 'Medicine',
        subject: 'Internal Med',
        cards: 4),
    _deck(2, 'Arrhythmias',
        lessonId: 10,
        lessonTitle: 'Cardiology',
        chapterId: 100,
        chapterTitle: 'Medicine',
        cards: 2),
    _deck(3, 'Asthma one-liners',
        lessonId: 11,
        lessonTitle: 'Pulmonology',
        chapterId: 100,
        chapterTitle: 'Medicine',
        cards: 3),
    _deck(4, 'Labour stages',
        lessonId: 20,
        lessonTitle: 'Obstetrics',
        chapterId: 200,
        chapterTitle: 'Obstetrics & Gynaecology',
        cards: 6),
    // No lesson, so no chapter either — the course-wide deck.
    _deck(5, 'Exam day checklist', cards: 1),
  ],
};

/// A note the length the live data actually has — the one card in production
/// carries several paragraphs. Short fixtures are how a cramped scroll box
/// passes its tests.
final String _longNote = 'Inferior MI — II, III, aVF.\n\n' +
    List.generate(
      30,
      (i) => 'Line $i: reciprocal changes in I and aVL, '
          'right-sided leads if RV involvement is suspected.',
    ).join('\n\n');

final Map<String, dynamic> _deckOneDetail = {
  'rapidRecall': {
    ..._deck(1, 'ECG rapid recall',
        lessonId: 10,
        lessonTitle: 'Cardiology',
        chapterId: 100,
        chapterTitle: 'Medicine',
        subject: 'Internal Med',
        cards: 2,
        noteUrl: 'https://example.test/handout.pdf'),
    'cards': [
      {
        'id': 11,
        'imageUrl': 'https://example.test/ecg1.png',
        'note': _longNote,
        'displayOrder': 0,
      },
      {
        'id': 12,
        'imageUrl': null,
        'note': 'Anterior MI — V1 to V4',
        'displayOrder': 1,
      },
    ],
  },
};

class _FakeRecallService extends RapidRecallService {
  final Map<String, dynamic> list;
  final Map<int, Map<String, dynamic>> details;
  int listCalls = 0;
  int deckCalls = 0;

  /// Deck fetches running at once, and the most there ever were.
  int _running = 0;
  int maxRunning = 0;

  /// How long a deck fetch takes. Zero still yields a turn of the event
  /// loop; a real duration lets a test see the wait itself.
  final Duration delay;

  _FakeRecallService({
    Map<String, dynamic>? list,
    this.details = const {},
    this.delay = Duration.zero,
  }) : list = list ?? _listResponse;

  @override
  Future<RapidRecallList> fetchAll() async {
    listCalls++;
    // Through the real parser, so the shape of the live response is what is
    // under test and not a hand-built object.
    return RapidRecallService.parseList(this.list);
  }

  @override
  Future<RapidRecallDeck> fetchDeck(int id) async {
    deckCalls++;
    _running++;
    if (_running > maxRunning) maxRunning = _running;
    try {
      // A turn of the event loop, so overlapping fetches actually overlap.
      await Future<void>.delayed(delay);
      final raw = details[id]?['rapidRecall'];
      if (raw == null) {
        throw QuizException(QuizErrorKind.lessonNotFound, 'Deck not found');
      }
      return RapidRecallDeck.fromJson(Map<String, dynamic>.from(raw as Map));
    } finally {
      _running--;
    }
  }
}

Future<RapidRecallProvider> _loaded([_FakeRecallService? service]) async {
  final provider = RapidRecallProvider(service: service ?? _FakeRecallService());
  await provider.load();
  return provider;
}

Future<void> _pump(WidgetTester tester, RapidRecallProvider provider,
    Widget screen) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RapidRecallProvider>.value(value: provider),
        // The Recall nav bar marks the tabs the plan does not cover.
        ChangeNotifierProvider(create: (_) => PlanAccessProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(440, 956),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(home: screen),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('parsing', () {
    test('a deck reads every optional field, present or absent', () {
      final list = RapidRecallService.parseList(_listResponse);
      expect(list.decks, hasLength(5));
      expect(list.reason, isNull);

      final filed = list.decks.first;
      expect(filed.title, 'ECG rapid recall');
      expect(filed.lesson?.chapter?.title, 'Medicine');
      expect(filed.subject?.name, 'Internal Med');
      expect(filed.cardCount, 4);
      // The list response carries no cards at all, which is not the same as
      // a deck with none.
      expect(filed.cards, isEmpty);
      expect(filed.hasHandout, isFalse);

      final courseWide = list.decks.last;
      expect(courseWide.lesson, isNull);
      expect(courseWide.subject, isNull);
    });

    test('the empty-with-a-reason response keeps its sentence', () {
      // The server's own answer when no course is selected. Showing an empty
      // shelf instead would be the wrong one.
      final list = RapidRecallService.parseList(
        {'rapidRecalls': [], 'reason': 'No course selected yet.'},
      );
      expect(list.decks, isEmpty);
      expect(list.reason, 'No course selected yet.');
    });

    test('a card is an image, a note, or both', () {
      final deck = RapidRecallDeck.fromJson(
          Map<String, dynamic>.from(_deckOneDetail['rapidRecall'] as Map));

      expect(deck.cards, hasLength(2));
      expect(deck.cards.first.hasImage, isTrue);
      expect(deck.cards.first.hasNote, isTrue);
      expect(deck.cards.last.hasImage, isFalse);
      expect(deck.cards.last.hasNote, isTrue);
      expect(deck.hasHandout, isTrue);
      expect(deck.noteFileType, 'pdf');
    });
  });

  group('grouping', () {
    test('topics are the chapters, with the catch-all last', () async {
      final provider = await _loaded();
      final topics = provider.topics;

      expect(topics.map((t) => t.title),
          ['Medicine', 'Obstetrics & Gynaecology', 'General']);
      // Three decks under Medicine, nine cards between them.
      expect(topics.first.decks, hasLength(3));
      expect(topics.first.cardCount, 9);
      expect(topics.first.summary, '3 decks · 9 cards');
      expect(topics.last.id, isNull);
    });

    test('a topic opens onto its lessons, and a lesson onto its decks',
        () async {
      final provider = await _loaded();

      final lessons = provider.lessonsIn(100);
      expect(lessons.map((l) => l.title), ['Cardiology', 'Pulmonology']);

      final decks = provider.decksIn(chapterId: 100, lessonId: 10);
      expect(decks.map((d) => d.title), ['ECG rapid recall', 'Arrhythmias']);

      // The course-wide deck is reachable, not stranded.
      expect(provider.decksIn(chapterId: null, lessonId: null).single.title,
          'Exam day checklist');
    });

    test('one deck says what is in it', () async {
      final provider = await _loaded();
      final deck = provider.decksIn(chapterId: 100, lessonId: 10).first;
      expect(deck.summary, 'Internal Med · 4 cards');
      // No subject: just the count, not a stray separator.
      expect(provider.decksIn(chapterId: 200, lessonId: 20).single.summary,
          '6 cards');
    });
  });

  group('a deck filed under a subject, with no lesson', () {
    // The case that was broken: read through the lesson, these fell into
    // "General", where a student looking under Internal Medicine never sees
    // them.
    final service = _FakeRecallService(list: {
      'rapidRecalls': [
        _deck(1, 'ECG rapid recall',
            lessonId: 10,
            lessonTitle: 'Cardiology',
            chapterId: 100,
            chapterTitle: 'Internal Medicine',
            cards: 2),
        _deck(2, 'All of Internal Medicine',
            chapterId: 100, chapterTitle: 'Internal Medicine', cards: 9),
        _deck(3, 'Exam day checklist', cards: 1),
      ],
    });

    test('lands under its own subject, not General', () async {
      final provider = await _loaded(service);

      expect(provider.topics.map((t) => t.title),
          ['Internal Medicine', 'General']);
      expect(provider.topics.first.decks.map((d) => d.title),
          ['ECG rapid recall', 'All of Internal Medicine']);
      // Only the deck with no chapter at all is General.
      expect(provider.topics.last.decks.single.title, 'Exam day checklist');
    });

    test('sits in a group named after the subject, after the lessons',
        () async {
      final provider = await _loaded(service);
      final groups = provider.lessonsIn(100);

      expect(groups.map((g) => g.title), ['Cardiology', 'All Internal Medicine']);
      expect(groups.last.decks.single.title, 'All of Internal Medicine');
    });

    test('opens from that group, and knows its siblings', () async {
      final provider = await _loaded(service);

      expect(
        provider.decksIn(chapterId: 100, lessonId: null).single.title,
        'All of Internal Medicine',
      );
      // A deck in the chapter's own group is not a sibling of a lesson's deck.
      expect(provider.siblingsOf(2), isEmpty);
      expect(provider.siblingsOf(1), isEmpty);
    });

    test('a deck pinned to a lesson is where it always was', () async {
      final provider = await _loaded(service);

      expect(provider.decksIn(chapterId: 100, lessonId: 10).single.title,
          'ECG rapid recall');
    });
  });

  group('loading', () {
    test('callers share one request', () async {
      // Four screens read this list and the topmost is pushed twice in a
      // second — the same response fetched twice is the delay the client
      // reported on every other screen.
      final service = _FakeRecallService();
      final provider = RapidRecallProvider(service: service);

      await Future.wait([provider.load(), provider.load(), provider.load()]);
      expect(service.listCalls, 1);

      // A later call is its own request: a deck published while the student
      // is in the app still turns up.
      await provider.load();
      expect(service.listCalls, 2);
    });

    test('a deck opened twice is fetched once per visit, not per caller',
        () async {
      final service =
          _FakeRecallService(details: {1: _deckOneDetail});
      final provider = await _loaded(service);

      await Future.wait([provider.loadDeck(1), provider.loadDeck(1)]);
      expect(service.deckCalls, 1);
      expect(provider.deck(1)!.cards, hasLength(2));
      expect(provider.hasCards(1), isTrue);
    });

    test("one deck's failure stays on that deck", () async {
      // Thumbnails warm decks in the background. One of those failing must
      // not put its error on the screen of a deck that loaded fine.
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));

      await provider.loadDeck(1);
      await provider.loadDeck(2); // no fixture — a 404

      expect(provider.deckError(2), 'Deck not found');
      expect(provider.deckError(1), isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.hasCards(1), isTrue);
    });

    test('a loaded deck offers its first image as a thumbnail', () async {
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));
      // The list row has no cards, so nothing to show yet.
      expect(provider.deck(1)!.coverImageUrl, isNull);

      await provider.loadDeck(1);
      expect(provider.deck(1)!.coverImageUrl, 'https://example.test/ecg1.png');
    });

    test("a deck's siblings are the rest of its lesson", () async {
      final provider = await _loaded();

      // Cardiology holds decks 1 and 2.
      expect(provider.siblingsOf(1).map((d) => d.title), ['Arrhythmias']);
      expect(provider.siblingsOf(2).map((d) => d.title), ['ECG rapid recall']);
      // Pulmonology holds only deck 3 — same chapter, different lesson, so
      // Cardiology's decks are not offered.
      expect(provider.siblingsOf(3), isEmpty);
      // The course-wide deck is alone in General.
      expect(provider.siblingsOf(5), isEmpty);
      // An id not in the list: nothing, not a throw.
      expect(provider.siblingsOf(99), isEmpty);
    });

    test('the row from the list stands in until the cards arrive', () async {
      final provider = await _loaded();
      // Enough to draw the header while the cards are still coming.
      expect(provider.deck(1)!.title, 'ECG rapid recall');
      expect(provider.hasCards(1), isFalse);
    });
  });

  group('bookmarks', () {
    test('a toggle survives a restart', () async {
      final provider = await _loaded();
      provider.toggleBookmark(4);
      expect(provider.isBookmarked(4), isTrue);

      // Written in the background, so the write has to land before a new
      // provider reads it.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final restarted = RapidRecallProvider(service: _FakeRecallService());
      await restarted.load();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(restarted.isBookmarked(4), isTrue);
      expect(restarted.isBookmarked(1), isFalse,
          reason: 'only the deck that was toggled');
    });

    test('an opened deck stays opened after a restart', () async {
      // The accent on a deck row means "not opened yet". If it came back
      // after every launch it would mean nothing.
      final provider = await _loaded();
      expect(provider.isOpened(3), isFalse);
      provider.markOpened(3);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final restarted = RapidRecallProvider(service: _FakeRecallService());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(restarted.isOpened(3), isTrue);
      expect(restarted.isOpened(4), isFalse);
    });

    test('sign-out takes the decks and the bookmarks with it', () async {
      final provider = await _loaded();
      provider.toggleBookmark(1);

      provider.clear();
      expect(provider.decks, isEmpty);
      expect(provider.isBookmarked(1), isFalse);
    });
  });

  group('screens', () {
    testWidgets('topic chips switch the lessons in place', (tester) async {
      final provider = await _loaded();
      await _pump(tester, provider, const RecallTopicsScreen());

      expect(find.text('Rapid Recall'), findsOneWidget);
      expect(find.text('Topics'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);

      // The first topic is chosen on arrival, so there is no empty screen
      // waiting on a tap.
      expect(find.text('Cardiology'), findsOneWidget);
      expect(find.text('2 decks · 6 cards'), findsOneWidget);
      expect(find.text('Pulmonology'), findsOneWidget);

      await tester.tap(find.text('Obstetrics & Gynaecology'));
      await tester.pumpAndSettle();
      expect(find.text('Obstetrics'), findsOneWidget);
      expect(find.text('Cardiology'), findsNothing);

      await tester.tap(find.text('Medicine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardiology'));
      await tester.pumpAndSettle();

      expect(find.byType(RecallDecksScreen), findsOneWidget);
      expect(find.text('ECG rapid recall'), findsOneWidget);
      expect(find.text('Internal Med · 4 cards'), findsOneWidget);
    });

    testWidgets('lessons get an icon from their name', (tester) async {
      expect(recallIconFor('Cardiology'), Icons.favorite_border_rounded);
      expect(recallIconFor('Gastroenterology & Hepatology'),
          Icons.restaurant_outlined);
      expect(recallIconFor('Obstetrics'), Icons.pregnant_woman_rounded);
      // Nothing recognisable: a book, not a crash or a blank circle.
      expect(recallIconFor('testing'), Icons.menu_book_rounded);
    });

    testWidgets('the bookmark on a deck row flips without opening it',
        (tester) async {
      final provider = await _loaded();
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );

      expect(find.byIcon(Icons.bookmark_border_rounded), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded).first);
      await tester.pumpAndSettle();

      expect(provider.isBookmarked(1), isTrue);
      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      // Still on the list — the bookmark is its own hit target.
      expect(find.byType(RecallCardsScreen), findsNothing);
    });

    testWidgets('an unopened deck is marked, and opening it clears the mark',
        (tester) async {
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );

      RecallDeckTile tileFor(String title) => tester.widget<RecallDeckTile>(
            find.ancestor(
              of: find.text(title),
              matching: find.byType(RecallDeckTile),
            ),
          );

      expect(tileFor('ECG rapid recall').isNew, isTrue);

      await tester.tap(find.text('ECG rapid recall'));
      await tester.pumpAndSettle();
      expect(find.byType(RecallCardsScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(tileFor('ECG rapid recall').isNew, isFalse);
      // Only the deck that was opened.
      expect(tileFor('Arrhythmias').isNew, isTrue);
    });

    testWidgets('a long lesson shows four decks until View all',
        (tester) async {
      final provider = await _loaded(_FakeRecallService(list: {
        'rapidRecalls': [
          for (var i = 1; i <= 6; i++)
            _deck(i, 'Deck $i',
                lessonId: 10,
                lessonTitle: 'Cardiology',
                chapterId: 100,
                chapterTitle: 'Medicine'),
        ],
      }));
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );

      expect(find.byType(RecallDeckTile), findsNWidgets(RecallDecksScreen.preview));
      expect(find.text('Deck 5'), findsNothing);

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();

      expect(find.text('Deck 5'), findsOneWidget);
      expect(find.text('Deck 6'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets(
        'thumbnails load one deck at a time, only for rows on screen',
        (tester) async {
      Map<String, dynamic> detail(int id) => {
            'rapidRecall': {
              ..._deck(id, 'Deck $id',
                  lessonId: 10,
                  lessonTitle: 'Cardiology',
                  chapterId: 100,
                  chapterTitle: 'Medicine'),
              'cards': [
                {'id': id * 10, 'imageUrl': null, 'note': 'Notes first'},
                {
                  'id': id * 10 + 1,
                  'imageUrl': 'https://example.test/deck$id.png',
                  'note': null,
                },
              ],
            },
          };

      final service = _FakeRecallService(
        list: {
          'rapidRecalls': [
            for (var i = 1; i <= 6; i++)
              _deck(i, 'Deck $i',
                  lessonId: 10,
                  lessonTitle: 'Cardiology',
                  chapterId: 100,
                  chapterTitle: 'Medicine'),
          ],
        },
        details: {for (var i = 1; i <= 6; i++) i: detail(i)},
      );
      final provider = await _loaded(service);
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );
      await tester.pumpAndSettle();

      // The first card is notes only, so the thumbnail is the first card
      // that has an image — not simply card one.
      final first = tester.widget<RecallDeckTile>(find.byType(RecallDeckTile).first);
      expect(first.coverUrl, 'https://example.test/deck1.png');

      expect(service.deckCalls, RecallDecksScreen.preview,
          reason: 'rows hidden behind View all are not fetched');
      expect(service.maxRunning, 1,
          reason: 'one at a time, so the foreground is never starved');

      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(service.deckCalls, 6);
      expect(service.maxRunning, 1);
    });

    testWidgets('a warmed deck opens with no wait', (tester) async {
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ECG rapid recall'));
      // One frame for the route, no settling: the cards are already here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Inferior MI'), findsOneWidget);
    });

    testWidgets('a thumbnail on its way animates, and stops once it settles',
        (tester) async {
      final provider = await _loaded(_FakeRecallService(
        details: {1: _deckOneDetail},
        delay: const Duration(milliseconds: 300),
      ));
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );

      RecallDeckTile tile(String title) => tester.widget<RecallDeckTile>(
            find.ancestor(
              of: find.text(title),
              matching: find.byType(RecallDeckTile),
            ),
          );

      // Nothing fetched yet: the rows say something is coming, rather than
      // showing an icon they are about to swap out.
      expect(tile('ECG rapid recall').coverLoading, isTrue);
      expect(tile('Arrhythmias').coverLoading, isTrue);
      expect(find.byType(LoadingDots), findsNWidgets(2));

      await tester.pumpAndSettle();

      expect(tile('ECG rapid recall').coverLoading, isFalse);
      expect(tile('ECG rapid recall').coverUrl, 'https://example.test/ecg1.png');
      // Deck 2 has no fixture, so its fetch failed. A failure must stop the
      // animation, not leave it running over nothing.
      expect(tile('Arrhythmias').coverLoading, isFalse);
      expect(tile('Arrhythmias').coverUrl, isNull);
      // pumpAndSettle returning at all is the proof nothing still animates.
    });

    testWidgets('a short lesson has no View all to tap', (tester) async {
      final provider = await _loaded();
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );
      // Lets the background thumbnail warm finish, so it does not outlive
      // the test.
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('a deck opens on its cards, counted', (tester) async {
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));
      await _pump(tester, provider, const RecallCardsScreen(deckId: 1));
      // The fetch is deferred to after the first frame, so the cards land on
      // the next one.
      await tester.pumpAndSettle();

      expect(find.textContaining('Inferior MI'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      // The handout moved to the app bar with the row under the image.
      expect(find.byTooltip('Open handout'), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Anterior MI — V1 to V4'), findsOneWidget);
      // A card with no image still says where it is in the deck.
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('image, then the note — no row between them, scrolling as one',
        (tester) async {
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));
      await _pump(tester, provider, const RecallCardsScreen(deckId: 1));
      await tester.pumpAndSettle();

      final counter = find.text('1/2');
      final note = find.textContaining('Inferior MI');
      expect(tester.getTopLeft(counter).dy,
          lessThan(tester.getTopLeft(note).dy));

      // The title shows once, in the app bar. The row under the image
      // repeated it, and it is gone.
      expect(find.text('ECG rapid recall'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('ECG rapid recall'),
          matching: find.byType(AppBar),
        ),
        findsOneWidget,
      );

      final before = tester.getTopLeft(note).dy;
      await tester.drag(find.byType(PageView), const Offset(0, -220));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(note).dy, lessThan(before),
          reason: 'the page itself scrolled, not a box inside it');
    });

    testWidgets('the bookmark still works from the app bar', (tester) async {
      final provider =
          await _loaded(_FakeRecallService(details: {1: _deckOneDetail}));
      await _pump(tester, provider, const RecallCardsScreen(deckId: 1));
      await tester.pumpAndSettle();

      // By tooltip, not icon: the "More in" rows below carry bookmark icons
      // of their own.
      await tester.tap(find.byTooltip('Bookmark'));
      await tester.pump();
      expect(provider.isBookmarked(1), isTrue);
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove bookmark'));
      await tester.pump();
      expect(provider.isBookmarked(1), isFalse);
    });

    testWidgets(
        'the other decks are listed under a deck, and open in its place',
        (tester) async {
      final provider = await _loaded(_FakeRecallService(details: {
        1: _deckOneDetail,
        2: {
          'rapidRecall': {
            ..._deck(2, 'Arrhythmias',
                lessonId: 10,
                lessonTitle: 'Cardiology',
                chapterId: 100,
                chapterTitle: 'Medicine'),
            'cards': [
              {'id': 21, 'imageUrl': null, 'note': 'AF — irregularly irregular'},
            ],
          },
        },
      }));
      // Starting from the list, so the back step at the end has somewhere
      // real to land.
      await _pump(
        tester,
        provider,
        const RecallDecksScreen(chapterId: 100, lessonId: 10, title: 'Cardiology'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ECG rapid recall'));
      await tester.pumpAndSettle();
      expect(find.byType(RecallCardsScreen), findsOneWidget);

      // At the foot of the card, under a long note.
      final page = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      final heading = find.text('More in Cardiology');
      await tester.scrollUntilVisible(heading, 400, scrollable: page.first);
      expect(heading, findsOneWidget);
      expect(find.text('1 deck'), findsOneWidget);
      // Only the others — the deck on screen is not offered to itself.
      expect(
        find.descendant(
          of: find.byType(RecallDeckTile),
          matching: find.text('ECG rapid recall'),
        ),
        findsNothing,
      );

      final next = find.text('Arrhythmias');
      await tester.scrollUntilVisible(next, 200, scrollable: page.first);
      await tester.tap(next);
      await tester.pumpAndSettle();

      expect(find.text('AF — irregularly irregular'), findsOneWidget);
      expect(
        tester.widget<RecallCardsScreen>(find.byType(RecallCardsScreen)).deckId,
        2,
      );
      // Its own list offers deck 1 back.
      expect(provider.siblingsOf(2).single.id, 1);

      // Replaced, not stacked: one back goes to the list, not to deck 1.
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(RecallCardsScreen), findsNothing);
      expect(find.byType(RecallDecksScreen), findsOneWidget);
    });

    testWidgets('a deck alone in its lesson offers nothing further',
        (tester) async {
      final provider = await _loaded(_FakeRecallService(details: {
        3: {
          'rapidRecall': {
            ..._deck(3, 'Asthma one-liners',
                lessonId: 11,
                lessonTitle: 'Pulmonology',
                chapterId: 100,
                chapterTitle: 'Medicine'),
            'cards': [
              {'id': 31, 'imageUrl': null, 'note': 'Wheeze is not always asthma'},
            ],
          },
        },
      }));
      await _pump(tester, provider, const RecallCardsScreen(deckId: 3));
      await tester.pumpAndSettle();

      expect(find.text('Wheeze is not always asthma'), findsOneWidget);
      expect(find.textContaining('More in'), findsNothing);
      // No handout on this deck, so no button promising one.
      expect(find.byTooltip('Open handout'), findsNothing);
      expect(find.byTooltip('Bookmark'), findsOneWidget);
      expect(find.byType(RecallDeckTile), findsNothing);
    });

    testWidgets('pulling the list down refetches it', (tester) async {
      // Counted from after the screen has settled: it refreshes itself on
      // first appearance too, and that one is not what this is testing. The
      // pull must add exactly one fetch on top of it.
      final service = _FakeRecallService();
      final provider = RapidRecallProvider(service: service);
      await _pump(tester, provider, const RecallTopicsScreen());
      await tester.pumpAndSettle();
      final beforePull = service.listCalls;

      // A drag, not a fling: a fling's momentum can trip the indicator more
      // than once, and the count is the point.
      await tester.drag(find.text('Cardiology'), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(service.listCalls, beforePull + 1);
    });

    testWidgets("an empty shelf says the server's reason, not 'nothing here'",
        (tester) async {
      final provider = await _loaded(_FakeRecallService(
        list: {'rapidRecalls': [], 'reason': 'No course selected yet.'},
      ));
      await _pump(tester, provider, const RecallTopicsScreen());

      expect(find.text('No course selected yet.'), findsOneWidget);
      expect(find.text('No recall cards here yet.'), findsNothing);
    });
  });
}
