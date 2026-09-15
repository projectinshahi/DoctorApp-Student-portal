import 'package:dr_app/repository/profile_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ProfileProvider restores its cached profile on construction.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('overlapping callers share one request', () async {
    // The home screen and the profile screen both refresh on becoming
    // visible, and moving between them lands both within a second.
    final provider = ProfileProvider();

    final a = provider.loadProfile();
    final b = provider.loadProfile();

    // The same future, not two — which is what makes it one request.
    expect(identical(a, b), isTrue);

    await Future.wait([a, b]).catchError((_) => <void>[]);
  });

  test('a later call is its own request — sharing, not caching', () async {
    // An edited name has to show up.
    final provider = ProfileProvider();

    final first = provider.loadProfile();
    await first.catchError((_) {});
    final second = provider.loadProfile();

    expect(identical(first, second), isFalse);
    await second.catchError((_) {});
  });
}
