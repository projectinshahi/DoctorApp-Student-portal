import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the gate must decide once the local flag is missing.
///
/// Mirrors `AuthProvider.resolveExamSelection`, which needs a live socket to
/// run. The rule is the part that broke: a purely local boolean sent every
/// reinstalled app back to the course picker.
enum GateDecision { home, askForCourse, keepWaiting }

GateDecision decide({
  required bool localFlag,
  required bool requestSucceeded,
  required SelectionContentModel? content,
}) {
  if (localFlag) return GateDecision.home;

  // A failed call means "we do not know". Sending a returning student to the
  // picker because their connection dropped is the same bug in a new coat.
  if (!requestSucceeded) return GateDecision.keepWaiting;

  return content?.hasSelection == true
      ? GateDecision.home
      : GateDecision.askForCourse;
}

SelectionContentModel _withCourse() => SelectionContentModel(
      course: SelectedCourseInfo(
          id: 22, title: 'GP GULF LICENSING EXAM', accessType: 'free'),
      chapters: const [],
    );

SelectionContentModel _withoutCourse() =>
    SelectionContentModel(chapters: const []);

void main() {
  test('the local flag alone is enough to go home', () {
    expect(
      decide(localFlag: true, requestSucceeded: true, content: null),
      GateDecision.home,
    );
  });

  test('a reinstalled app asks the server instead of the student', () {
    // The regression: flag gone with the app data, but the account has had a
    // course for months. Asking again is the bug.
    expect(
      decide(
          localFlag: false, requestSucceeded: true, content: _withCourse()),
      GateDecision.home,
    );
  });

  test('a genuinely new student is asked to choose', () {
    expect(
      decide(
          localFlag: false, requestSucceeded: true, content: _withoutCourse()),
      GateDecision.askForCourse,
    );
  });

  test('a failed request never sends a returning student to the picker', () {
    // Guessing "new student" on a dropped connection would make them pick a
    // course they already have — and overwrite it.
    expect(
      decide(localFlag: false, requestSucceeded: false, content: null),
      GateDecision.keepWaiting,
    );
  });

  test('hasSelection is what a course means', () {
    expect(_withCourse().hasSelection, isTrue);
    expect(_withoutCourse().hasSelection, isFalse);
  });

  group('the four cases, end to end', () {
    test('1. a brand new student is asked to choose', () {
      expect(
        decide(
            localFlag: false, requestSucceeded: true, content: _withoutCourse()),
        GateDecision.askForCourse,
      );
    });

    test('2. reaching the picker and quitting without choosing asks again', () {
      // Nothing was saved, so the server still has no course and the local
      // flag is still false. Reopening must land back on the picker rather
      // than on an empty home screen.
      expect(
        decide(
            localFlag: false, requestSucceeded: true, content: _withoutCourse()),
        GateDecision.askForCourse,
      );
    });

    test('3. choosing a course goes home, and stays home next launch', () {
      // Right after choosing: the flag is set in the same step the selection
      // is saved.
      expect(
        decide(localFlag: true, requestSucceeded: true, content: _withCourse()),
        GateDecision.home,
      );

      // Next launch, even on a wiped install, the server answers for it.
      expect(
        decide(localFlag: false, requestSucceeded: true, content: _withCourse()),
        GateDecision.home,
      );
    });

    test('4. an existing student on a new phone is never re-asked', () {
      expect(
        decide(localFlag: false, requestSucceeded: true, content: _withCourse()),
        GateDecision.home,
      );
    });
  });

  group('the flag must not outlive the account', () {
    // hasSelectedExam answers "has *this account* picked a course?", but it
    // lives in device storage. Left behind on sign-out, the next person to
    // sign in on the same phone inherited the previous student's answer.

    test('a stale true flag would send a course-less account to home', () {
      // What the bug looked like: student A picks a course, signs out, and
      // student B — or A on a fresh account — lands on an empty home screen
      // having never chosen anything.
      expect(
        decide(localFlag: true, requestSucceeded: true, content: _withoutCourse()),
        GateDecision.home,
        reason: 'this is why the flag has to be cleared with the tokens, '
            'not merely reset in memory',
      );
    });

    test('cleared, the same account resolves correctly from the server', () {
      // No course on the server -> the picker, every launch, until they pick.
      expect(
        decide(localFlag: false, requestSucceeded: true, content: _withoutCourse()),
        GateDecision.askForCourse,
      );

      // A course on the server -> straight home, no picker, for a returning
      // student on any device.
      expect(
        decide(localFlag: false, requestSucceeded: true, content: _withCourse()),
        GateDecision.home,
      );
    });
  });
}
