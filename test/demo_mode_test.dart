import 'package:dr_app/View_model/profile_model.dart';
import 'package:dr_app/core/demo/demo_content.dart';
import 'package:dr_app/repository/rapid_recall_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dr_app/core/utils/youtube_utils.dart';
import 'package:dr_app/repository/profile_provider.dart';
import 'package:dr_app/models/daily_quiz_model.dart';
import 'package:dr_app/repository/daily_quiz_provider.dart';
import 'package:dr_app/repository/quiz_provider.dart';
import 'package:dr_app/models/home_summary_model.dart';
import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The preview is the real screens reading sample content, so the sample has
/// to parse exactly as a server response does. If a model ever stops
/// accepting it, the preview breaks before anyone opens the app.
void main() {
  tearDown(DemoMode.reset);

  test('the sample course tree parses as a real one', () {
    final content = SelectionContentModel.fromJson(DemoContent.courseTree);

    expect(content.course?.title, 'GP Gulf Licensing Exam');
    expect(content.chapters, hasLength(2));
    expect(content.chapters.first.lessons, hasLength(6));
  });

  test('every sample video is a link the player can open', () {
    // A free video lesson whose url goes nowhere reads as a broken player.
    final videos = SelectionContentModel.fromJson(DemoContent.courseTree)
        .chapters
        .expand((c) => c.lessons)
        .where((l) => l.isVideo && !l.isPremium)
        .toList();

    expect(videos, hasLength(3));

    for (final video in videos) {
      expect(video.isOpen, isTrue);
      // The lesson screen routes on this, and then needs an id out of it.
      expect(YoutubeUtils.isYoutubeUrl(video.videoUrl!), isTrue);
      expect(YoutubeUtils.extractVideoId(video.videoUrl!), isNotNull);
    }

    expect(videos.map((v) => v.videoUrl), DemoContent.sampleVideoUrls);
  });

  test('AI Videos shows the three free ones and three locked premium', () {
    final watchable = SelectionContentModel.fromJson(DemoContent.courseTree)
        .chapters
        .expand((c) => c.lessons)
        .where((l) => l.isWatchable)
        .toList();

    final free = watchable.where((l) => !l.isPremium);
    final premium = watchable.where((l) => l.isPremium);

    expect(free.map((l) => l.videoUrl), DemoContent.sampleVideoUrls);
    expect(premium, hasLength(3));
    for (final lesson in premium) {
      expect(lesson.isVideo, isTrue);
      // Shut, and nothing to play behind the padlock — a visitor is asked
      // to sign in rather than shown a player.
      expect(lesson.isOpen, isFalse);
      expect(lesson.hasVideo, isFalse);
    }
  });

  test('each free one carries its own still, so the list is not blank', () {
    final videos = SelectionContentModel.fromJson(DemoContent.courseTree)
        .chapters
        .expand((c) => c.lessons)
        .where((l) => l.isVideo && l.hasVideo);

    for (final video in videos) {
      expect(video.thumbnailUrl, isNotNull);
      expect(video.thumbnailUrl, contains('img.youtube.com'));
      // The still has to be of the video it sits above.
      expect(video.thumbnailUrl,
          contains(YoutubeUtils.extractVideoId(video.videoUrl!)!));
    }
  });

  test('a share link with its tracking parameter still resolves', () {
    // What gets pasted out of the YouTube app: youtu.be/ID?si=…
    const shared = 'https://youtu.be/28CYhgjrBLA?si=lWC-15NK1sK3z2FE';

    expect(YoutubeUtils.isYoutubeUrl(shared), isTrue);
    expect(YoutubeUtils.extractVideoId(shared), '28CYhgjrBLA');
  });

  test('the sample shows both a free lesson and a locked one', () {
    // A preview where everything is open says nothing about what a plan buys;
    // one where everything is locked shows nothing at all.
    final lessons = SelectionContentModel.fromJson(DemoContent.courseTree)
        .chapters
        .expand((c) => c.lessons);

    expect(lessons.where((l) => l.isOpen), isNotEmpty);
    expect(lessons.where((l) => !l.isOpen), isNotEmpty);
  });

  test('the sample day has a question that can be read', () {
    final set = DailyQuizSet.fromJson(DemoContent.dailyQuiz);

    expect(set.available, isTrue);
    expect(set.questions, isNotEmpty);
    expect(set.questions.first.options, hasLength(4));
  });

  test('the sample home summary carries the daily quiz', () {
    final home = HomeSummary.fromJson(DemoContent.homeSummary);

    expect(home.dailyQuiz, isNotNull);
    expect(home.dailyQuiz!.totalQuestions, 10);
    // Nothing in progress: there is no student to have started anything.
    expect(home.inProgressVideos, isEmpty);
  });

  test('the drawer has a guest to draw, not an error', () {
    // The profile screen shows "Failed to load profile" when it has nothing,
    // and a visitor opening the drawer would have hit exactly that.
    final profile = ProfileModel.fromJson(DemoContent.profile);

    expect(profile.name, 'Guest');
    expect(profile.email, 'Not signed in');
  });

  test('a signed-out provider has nothing of the last student left', () {
    // Logging out lands on the preview, which has to look like the app does
    // before anyone signs in — not like whoever just left.
    final profiles = ProfileProvider()
      ..profile = ProfileModel.fromJson({
        'id': 43,
        'name': 'Shareef',
        'email': 'shareef@example.test',
        'role': 'student',
        'status': 'verified',
      });

    profiles.clear();

    expect(profiles.profile, isNull);
  });

  test('the sample question can actually be answered', () async {
    // A preview where the one question does nothing is a screenshot. The
    // sample ships with its key, so the verdict is worked out on the device.
    DemoMode.active = true;
    final quiz = DailyQuizProvider(courseId: -1);
    await quiz.load();

    final question = quiz.questions.first;
    final correct = question.options.firstWhere((o) => o.isCorrect == true);

    await quiz.answer(question.id, correct.id);
    final verdict = quiz.answerFor(question.id);

    expect(verdict, isNotNull);
    expect(verdict!.isCorrect, isTrue);
    // And the reason, which a real set only gets back from the POST.
    expect(verdict.explanation, contains('FAST'));
  });

  test('a wrong answer is marked wrong, with the right one revealed', () async {
    DemoMode.active = true;
    final quiz = DailyQuizProvider(courseId: -1);
    await quiz.load();

    final question = quiz.questions.first;
    final wrong = question.options.firstWhere((o) => o.isCorrect != true);

    await quiz.answer(question.id, wrong.id);
    final verdict = quiz.answerFor(question.id)!;

    expect(verdict.isCorrect, isFalse);
    expect(verdict.correctOptionId, isNot(wrong.id));
  });

  test('the free subject opens and its questions can be answered', () async {
    // The complaint this fixes: a row marked Free that asked for an account
    // the moment it was tapped.
    DemoMode.active = true;
    final quiz = QuizProvider();
    await quiz.load(-102);

    expect(quiz.questions, hasLength(3));
    final question = quiz.questions.first;

    await quiz.answer(question.id, question.correctOptionId!);

    expect(quiz.isAnswered(question.id), isTrue);
    expect(quiz.resultFor(question)?.isCorrect, isTrue);
  });

  test('only the premium lesson is shut to a visitor', () {
    final lessons = SelectionContentModel.fromJson(DemoContent.courseTree)
        .chapters
        .expand((c) => c.lessons);

    final free = lessons.where((l) => !l.isPremium);
    expect(free, isNotEmpty);
    expect(free.every((l) => l.isOpen), isTrue,
        reason: 'free means open, signed in or not');
    expect(lessons.where((l) => l.isPremium).every((l) => !l.isOpen), isTrue);
  });

  test('Rapid Recall opens the free decks and keeps premium ones shut',
      () async {
    SharedPreferences.setMockInitialValues({});
    DemoMode.active = true;
    final recall = RapidRecallProvider();
    await recall.load();

    // One free and one premium deck per AI video, under that video's lesson.
    expect(recall.topics.map((t) => t.title), ['Internal Medicine']);
    expect(recall.lessonsIn(-11), hasLength(3));
    for (final lesson in recall.lessonsIn(-11)) {
      expect(lesson.decks.map((d) => d.accessType),
          containsAll(['free', 'premium']));
    }
    expect(recall.decks.where((d) => !d.locked), hasLength(3));
    expect(recall.decks.where((d) => d.locked), hasLength(3));
    // Every row has its picture before any deck is opened — the premium
    // ones too, whose cards a visitor never gets.
    expect(recall.decks.every((d) => d.coverImageUrl != null), isTrue);
    // The list carries counts, not cards — the same as the server's.
    expect(recall.decks.every((d) => d.cards.isEmpty && d.cardCount > 0),
        isTrue);

    for (final deck in recall.decks) {
      await recall.loadDeck(deck.id);
      if (deck.locked) {
        expect(recall.hasCards(deck.id), isFalse);
        expect(recall.deckNeedsPlan(deck.id), isTrue);
      } else {
        expect(recall.deck(deck.id)!.cards, hasLength(deck.cardCount));
        // Every free card is a frame from one of the AI videos plus its note.
        for (final card in recall.deck(deck.id)!.cards) {
          expect(card.hasNote, isTrue);
          expect(card.imageUrl, startsWith('https://img.youtube.com/vi/'));
        }
        expect(recall.deck(deck.id)!.coverImageUrl, isNotNull);
      }
    }
  });

  test('the preview is off unless it is switched on', () {
    expect(DemoMode.active, isFalse);
  });
}
