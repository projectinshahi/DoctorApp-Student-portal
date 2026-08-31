// lib/core/utils/refresh_on_visible.dart
import 'package:flutter/widgets.dart';

/// Watches route changes so screens can refetch whenever they become visible.
///
/// Registered once on the MaterialApp as a navigator observer. Without that
/// registration the mixin below is silently inert, which is the one way this
/// can go wrong.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// Refetches every time the screen becomes visible — when it is first pushed,
/// and again each time the screen above it is popped.
///
/// `initState` alone only covers the first of those: popping back does not
/// re-create the state, so a screen would keep showing the numbers it had
/// before the student went off and changed them. Every screen wiring that up
/// by hand is how the two paths drift apart, which is what this replaces.
///
/// Usage:
/// ```dart
/// class _FooState extends State<Foo> with RefreshOnVisible<Foo> {
///   @override
///   Future<void> onRefresh() => context.read<FooProvider>().load();
/// }
/// ```
mixin RefreshOnVisible<T extends StatefulWidget> on State<T> implements RouteAware {
  /// Fetch whatever this screen renders. Called on push and on return.
  Future<void> onRefresh();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// First appearance. Deferred to after the frame because [onRefresh] almost
  /// always notifies a provider, and notifying during build throws.
  @override
  void didPush() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onRefresh();
    });
  }

  /// Back from a screen pushed on top of this one — a finished quiz, a
  /// watched video, a purchase. This is the case `initState` cannot see.
  @override
  void didPopNext() {
    if (mounted) onRefresh();
  }

  @override
  void didPop() {}

  @override
  void didPushNext() {}
}
