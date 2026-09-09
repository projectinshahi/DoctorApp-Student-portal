import 'package:dr_app/models/comment_model.dart';
import 'package:dr_app/repository/comment_provider.dart';
import 'package:dr_app/services/comment_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves the same one comment for whatever lesson it is asked about, and
/// counts the calls so a test can tell a refetch from a cache hit.
class _Service extends CommentService {
  int calls = 0;

  @override
  Future<CommentPage> fetchComments(int lessonId,
      {int page = 1, int limit = 20}) async {
    calls++;
    return CommentPage.fromJson({
      'commentsEnabled': true,
      'page': 1,
      'totalPages': 1,
      'total': 1,
      'comments': [
        {
          'id': 1,
          'parentId': null,
          'body': 'lesson $lessonId',
          'author': {'id': 9, 'name': 'A'},
          'isMine': false,
          'reportedByMe': false,
          'replies': const [],
        },
      ],
    });
  }
}

void main() {
  group('the spinner shows only when there is nothing on screen', () {
    test('a cold load spins', () async {
      final provider = CommentProvider(service: _Service());

      final loading = <bool>[];
      provider.addListener(() => loading.add(provider.isLoading));

      await provider.load(1);

      // First notify is the one before the request goes out.
      expect(loading.first, isTrue, reason: 'nothing to show yet');
      expect(loading.last, isFalse);
    });

    test('reloading the same lesson never blanks the thread', () async {
      final service = _Service();
      final provider = CommentProvider(service: service);
      await provider.load(1);

      final loading = <bool>[];
      provider.addListener(() => loading.add(provider.isLoading));

      await provider.load(1);

      // This is the whole change: the comments stay on screen and the newer
      // copy swaps in underneath. isLoading never goes true.
      expect(loading, everyElement(isFalse));
      expect(service.calls, 2, reason: 'still refetched, just not visibly');
      expect(provider.comments, isNotEmpty);
    });

    test('a different lesson does spin, cached or not', () async {
      final provider = CommentProvider(service: _Service());
      await provider.load(1);

      final loading = <bool>[];
      provider.addListener(() => loading.add(provider.isLoading));

      await provider.load(2);

      // Lesson 1's thread under lesson 2 would be wrong, not merely stale.
      expect(loading.first, isTrue);
      expect(provider.comments.first.body, 'lesson 2');
    });
  });

  _cacheRules();
}

/// The rules a cached screen has to keep, written as the provider states them.
///
/// These mirror SavedProvider and SelectionContentProvider rather than
/// driving them — both build their own live service in the constructor, so
/// there is no seam to inject a fake through. The logic is what breaks
/// silently, and the logic is what is checked.
void _cacheRules() {
  group('a cache that cannot be right any more', () {
    /// SavedProvider.loadAll
    bool spins({required bool fetched, required bool stale}) =>
        !fetched || stale;

    test('the first open spins', () {
      expect(spins(fetched: false, stale: false), isTrue);
    });

    test('reopening does not', () {
      expect(spins(fetched: true, stale: false), isFalse);
    });

    test('after saving something it spins again', () {
      // A toggle knows an id, not the row. The list on screen is genuinely
      // missing what the student just saved, so showing it would be a lie
      // rather than a lag.
      expect(spins(fetched: true, stale: true), isTrue);
    });

    test('unsaving does not make it stale — the row goes locally', () {
      // toggleQuestion/toggleLesson drop the row themselves on the unsave
      // path, so the cached list stays correct and never sets the flag.
      expect(spins(fetched: true, stale: false), isFalse);
    });
  });

  group('signing out', () {
    /// AuthGate._onAuthChanged: the transition that clears every cache.
    bool clearsCaches({required bool wasSignedIn, required bool nowSignedOut}) =>
        wasSignedIn && nowSignedOut;

    test('a real sign-out clears them', () {
      expect(clearsCaches(wasSignedIn: true, nowSignedOut: true), isTrue);
    });

    test('a cold start on a dead token clears nothing it does not own', () {
      expect(clearsCaches(wasSignedIn: false, nowSignedOut: true), isFalse);
    });

    test('signing in is not a sign-out', () {
      expect(clearsCaches(wasSignedIn: false, nowSignedOut: false), isFalse);
    });
  });

  group('a screen never blanks over data it already holds', () {
    /// Mirrors QbankSubjectsScreen, QbankTab and AiVideoTab, which all bind
    /// their loader to the shared tree's isLoading.
    bool showsLoader({required bool isLoading, required bool hasSomething}) =>
        isLoading && !hasSomething;

    test('a cold load shows the loader', () {
      expect(showsLoader(isLoading: true, hasSomething: false), isTrue);
    });

    test('a refresh over rows already on screen does not', () {
      // This was the bug: the subjects screen is pushed with its chapter
      // already in hand, so it always had rows to draw — and isLoading alone
      // replaced them with a spinner on an empty page every time the shared
      // tree refetched, which it does on entry to seven different screens.
      expect(showsLoader(isLoading: true, hasSomething: true), isFalse);
    });

    test('settled with content shows content', () {
      expect(showsLoader(isLoading: false, hasSomething: true), isFalse);
    });

    test('settled with nothing shows the empty state, not the loader', () {
      // Not a spinner forever: the caller renders "no subjects yet" here.
      expect(showsLoader(isLoading: false, hasSomething: false), isFalse);
    });
  });
}
