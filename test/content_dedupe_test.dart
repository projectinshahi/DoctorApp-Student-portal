import 'dart:async';

import 'package:dr_app/models/selection_content_model.dart';
import 'package:dr_app/repository/selection_content_provider.dart';
import 'package:dr_app/services/selection_content_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts fetches and can hold one open, so overlapping callers are visible.
class _Service extends SelectionContentService {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<SelectionContentResult> fetchSelectionContent() async {
    calls++;
    if (gate != null) await gate!.future;
    return SelectionContentResult.success(
      SelectionContentModel(chapters: const []),
    );
  }
}

void main() {
  // SelectionContentProvider restores its cached tree on construction, so
  // the binding and a stub store have to exist before one is built.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('overlapping callers share one request', () async {
    // Seven screens fire loadContent on entry and navigating touches several
    // within a second. On device that queued eight fetches of the same three
    // chapters, and the waits stacked: 1.7s, 2.4s, 4.2s, 6.5s.
    final service = _Service()..gate = Completer<void>();
    final provider = SelectionContentProvider(service: service);

    final all = [
      provider.loadContent(),
      provider.loadContent(),
      provider.loadContent(),
      provider.loadContent(),
    ];

    expect(service.calls, 1, reason: 'three callers joined the first request');

    service.gate!.complete();
    await Future.wait(all);

    expect(service.calls, 1);
    expect(provider.content, isNotNull);
  });

  test('a later call still refetches — this is sharing, not caching',
      () async {
    // Returning to a screen must still pick up new scores and attempts. Only
    // *concurrent* callers share; a call after the first finished is its own.
    final service = _Service();
    final provider = SelectionContentProvider(service: service);

    await provider.loadContent();
    await provider.loadContent();

    expect(service.calls, 2);
  });

  test('a failed request does not wedge every later one', () async {
    // The in-flight future has to be cleared on failure too, or one bad
    // response would leave the app permanently joined to a dead request.
    final service = _Service()..gate = Completer<void>();
    final provider = SelectionContentProvider(service: service);

    final first = provider.loadContent();
    service.gate!.completeError(Exception('network'));
    await first.catchError((_) {});

    service.gate = null;
    await provider.loadContent();

    expect(service.calls, 2);
    expect(provider.content, isNotNull);
  });
}
