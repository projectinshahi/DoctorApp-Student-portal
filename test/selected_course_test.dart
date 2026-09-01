import 'package:dr_app/models/selection_content_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// The live shape of the content tree, trimmed to what the home card reads.
Map<String, dynamic> _content({
  required List<Map<String, dynamic>> chapters,
  Map<String, dynamic>? progress,
}) =>
    {
      'course': {
        'id': 22,
        'title': 'NEET-PG Complete',
        'thumbnail': null,
        'accessType': 'paid',
      },
      'hasPaid': true,
      'progress': progress,
      'chapters': chapters,
    };

Map<String, dynamic> _chapter({
  required int id,
  Map<String, dynamic>? progress,
}) =>
    {
      'id': id,
      'title': 'Chapter $id',
      'displayOrder': id,
      'lessons': const [],
      'progress': progress,
    };

void main() {
  test('modules count chapters, not lessons', () {
    final content = SelectionContentModel.fromJson(_content(
      // Four of six lessons done, but only one of three chapters finished.
      progress: {'completed': 4, 'total': 6, 'percent': 66},
      chapters: [
        _chapter(id: 1, progress: {'completed': 2, 'total': 2, 'percent': 100}),
        _chapter(id: 2, progress: {'completed': 2, 'total': 3, 'percent': 66}),
        _chapter(id: 3, progress: {'completed': 0, 'total': 1, 'percent': 0}),
      ],
    ));

    // Printing the lesson figure as modules would claim four chapters were
    // done when there are only three.
    expect(content.completedModules, 1);
    expect(content.totalModules, 3);
    expect(content.progress?.completedLessons, 4);
    expect(content.progress?.totalLessons, 6);
  });

  test('a chapter with no progress block is unknown, not unfinished', () {
    final content = SelectionContentModel.fromJson(_content(
      chapters: [
        _chapter(id: 1, progress: {'completed': 1, 'total': 1, 'percent': 100}),
        _chapter(id: 2),
      ],
    ));

    // Counting it as unfinished would show "1 of 2" for a course whose
    // second chapter the server said nothing about.
    expect(content.completedModules, 1);
    expect(content.totalModules, 1);
  });

  test('a course with no progress at all renders as zero, not a crash', () {
    final content = SelectionContentModel.fromJson(_content(chapters: const []));

    // A student who just picked a course opens this card before any lesson
    // has been touched. 0/0 must not divide.
    expect(content.course?.title, 'NEET-PG Complete');
    expect(content.progress, isNull);
    expect(content.completedModules, 0);
    expect(content.totalModules, 0);
  });
}
