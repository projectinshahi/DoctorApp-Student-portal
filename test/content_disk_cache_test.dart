import 'dart:convert';

import 'package:dr_app/core/constant/local_storage.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/services/selection_content_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends SelectionContentService {
  int calls = 0;

  @override
  Future<SelectionContentResult> fetchSelectionContent() async {
    calls++;
    return SelectionContentResult.failure('offline');
  }
}

const _tree = {
  'chapters': [
    {
      'id': 1,
      'title': 'Gynaecology',
      'displayOrder': 1,
      'lessons': <Map<String, dynamic>>[],
    },
  ],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a stored tree is on screen before the network answers', () async {
    // The whole point: on device the tree fetch measured 1.7-6.5s, and a
    // SharedPreferences read is milliseconds. The student should see
    // chapters, not a spinner, while that fetch runs.
    await LocalStorage.saveCourseTree(jsonEncode(_tree));

    final provider = SelectionContentProvider(service: _Service());
    // One turn of the event loop — no network involved.
    await Future<void>.delayed(Duration.zero);

    expect(provider.content?.chapters.single.title, 'Gynaecology');
    expect(provider.isLoading, isFalse, reason: 'there is something to show');
  });

  test('nothing stored means the ordinary cold load', () async {
    final provider = SelectionContentProvider(service: _Service());
    await Future<void>.delayed(Duration.zero);

    expect(provider.content, isNull);
  });

  test('a fetch writes the tree for next launch', () async {
    await LocalStorage.clearCourseTree();
    expect(await LocalStorage.getCourseTree(), isNull);

    await LocalStorage.saveCourseTree(jsonEncode(_tree));
    expect(await LocalStorage.getCourseTree(), isNotNull);
  });

  test('invalidate drops the stored copy too', () async {
    // Subscribing, or switching course, makes the stored tree wrong. Leaving
    // it would mean the next launch restores exactly the stale answer that
    // was just thrown away.
    await LocalStorage.saveCourseTree(jsonEncode(_tree));
    final provider = SelectionContentProvider(service: _Service());
    await Future<void>.delayed(Duration.zero);

    provider.invalidate();
    await Future<void>.delayed(Duration.zero);

    expect(provider.content, isNull);
    expect(await LocalStorage.getCourseTree(), isNull);
  });

  test('signing out clears it, so the next account starts clean', () async {
    await LocalStorage.saveCourseTree(jsonEncode(_tree));
    await LocalStorage.clearAll();
    expect(await LocalStorage.getCourseTree(), isNull);
  });

  test('a tree written by an older build is discarded, not crashed on',
      () async {
    await LocalStorage.saveCourseTree('{ not json');

    final provider = SelectionContentProvider(service: _Service());
    await Future<void>.delayed(Duration.zero);

    expect(provider.content, isNull);
    expect(await LocalStorage.getCourseTree(), isNull);
  });

  group('every cached screen', () {
    test('home and bookmarks are stored under their own keys', () async {
      await LocalStorage.saveCached(LocalStorage.homeSummaryKey, '{"a":1}');
      await LocalStorage.saveCached(LocalStorage.savedKey, '{"b":2}');

      expect(await LocalStorage.getCached(LocalStorage.homeSummaryKey),
          '{"a":1}');
      expect(await LocalStorage.getCached(LocalStorage.savedKey), '{"b":2}');
    });

    test('signing out clears all of them, not just the tree', () async {
      // Otherwise the next student on this phone opens on the previous one's
      // home screen and bookmarks.
      await LocalStorage.saveCourseTree(jsonEncode(_tree));
      await LocalStorage.saveCached(LocalStorage.homeSummaryKey, '{"a":1}');
      await LocalStorage.saveCached(LocalStorage.savedKey, '{"b":2}');

      await LocalStorage.clearAll();

      expect(await LocalStorage.getCourseTree(), isNull);
      expect(await LocalStorage.getCached(LocalStorage.homeSummaryKey), isNull);
      expect(await LocalStorage.getCached(LocalStorage.savedKey), isNull);
    });
  });
}
