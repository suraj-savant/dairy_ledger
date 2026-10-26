import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'logger.dart';

/// Logs every provider state change in debug builds (tag `STATE`), e.g.
/// `[STATE] profileProvider: AsyncLoading -> AsyncData(UserProfile(...))`.
base class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    logd('STATE', '$name: ${_short(previousValue)} -> ${_short(newValue)}');
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    logd('STATE', '$name FAILED: $error');
  }

  static String _short(Object? v) {
    final s = '$v';
    return s.length > 90 ? '${s.substring(0, 90)}…' : s;
  }
}
