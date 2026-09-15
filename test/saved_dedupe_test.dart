import 'dart:async';

import 'package:dr_app/models/saved_model.dart';
import 'package:dr_app/repository/saved_provider.dart';
import 'package:dr_app/services/saved_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends SavedService {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<SavedBundle> fetchAll({String type = 'all'}) async {
    calls++;
    if (gate != null) await gate!.future;
    return SavedBundle.fromJson({
      'counts': {'all': 0, 'question': 0, 'lesson': 0},
      'questions': const [],
      'lessons': const [],
    });
  }
}

void main() {
  // SavedProvider restores its cache on construction.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('overlapping callers share one request', () async {
    // Five places call loadAll — the home screen, the QBank tab, the
    // bookmarks screen twice, and the sign-in warm-up. On device that showed
    // as the same 113-byte response fetched twice back to back, 2489ms and
    // 2526ms.
    final service = _Service()..gate = Completer<void>();
    final provider = SavedProvider(service: service);

    final all = [
      provider.loadAll(),
      provider.loadAll(),
      provider.loadAll(),
    ];
    expect(service.calls, 1);

    service.gate!.complete();
    await Future.wait(all);
    expect(service.calls, 1);
  });

  test('a later call still refetches — this is sharing, not caching',
      () async {
    // A bookmark added on another screen has to show up.
    final service = _Service();
    final provider = SavedProvider(service: service);

    await provider.loadAll();
    await provider.loadAll();

    expect(service.calls, 2);
  });

  test('a failure does not wedge every later call', () async {
    // The in-flight future must clear on failure too, or one bad response
    // would leave the app permanently joined to a dead request.
    final service = _Service()..gate = Completer<void>();
    final provider = SavedProvider(service: service);

    final first = provider.loadAll();
    service.gate!.completeError(Exception('offline'));
    await first.catchError((_) {});

    service.gate = null;
    await provider.loadAll();

    expect(service.calls, 2);
  });
}
