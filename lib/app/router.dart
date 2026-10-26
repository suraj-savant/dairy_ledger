import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/logger.dart';
import '../features/accounts/presentation/add_account_screen.dart';
import '../features/accounts/presentation/home_screen.dart';
import '../features/accounts/presentation/home_shell.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/bills/presentation/account_screen.dart';
import '../features/profile/presentation/onboarding_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/rates/presentation/rates_screen.dart';
import '../features/supplier/presentation/follow_account_screen.dart';
import '../features/supplier/presentation/supplier_account_screen.dart';
import '../features/supplier/presentation/supplier_home_screen.dart';
import '../features/supplier/providers/supplier_providers.dart';

/// Route paths in one place.
class Routes {
  Routes._();
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const rates = '/rates';
  static const analytics = '/analytics';
  static const addAccount = '/add-account';
  static const settings = '/settings';
  static const supplier = '/supplier';

  /// Shared link / QR code: `https://DOMAIN/a/ACCOUNT_ID`.
  static const sharedAccountPrefix = '/a/';
}

/// Re-runs the router redirect whenever sign-in, profile or the followed list changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(profileProvider, (_, _) => notifyListeners());
    ref.listen(followedAccountsProvider, (_, _) => notifyListeners());
    ref.listen(loginProvider, (_, _) => notifyListeners());
  }
}

/// Decides where the user belongs:
///
///  * shared link `/a/<id>`            -> always allowed (no login needed)
///  * signed out                       -> login, or the supplier list when
///                                        this phone already follows accounts
///  * signed in, onboarding not done   -> onboarding (cannot be skipped)
///  * signed in, onboarding done       -> the app
String? _redirect(Ref ref, GoRouterState state) {
  final loc = state.matchedLocation;
  String? go(String target) {
    if (target == loc) return null;
    logd('ROUTER', 'redirect $loc -> $target');
    return target;
  }

  if (loc.startsWith(Routes.sharedAccountPrefix)) return null;

  final auth = ref.read(authStateProvider);
  if (!auth.hasValue) return go(Routes.splash);

  final user = auth.value;
  if (user == null) {
    if (loc == Routes.login || loc.startsWith(Routes.supplier)) return null;
    if (loc == Routes.otp) {
      // The OTP screen needs a pending verification (lost after a restart).
      return ref.read(loginProvider).verificationId == null ? go(Routes.login) : null;
    }
    return go(ref.read(followedAccountsProvider).isNotEmpty ? Routes.supplier : Routes.login);
  }

  final profile = ref.read(profileProvider);
  if (!profile.hasValue) return go(Routes.splash); // loading, or failed (splash offers retry)

  final onboarded = profile.value?.onboardingCompleted ?? false;
  if (!onboarded) return go(Routes.onboarding);

  const entryScreens = {Routes.login, Routes.otp, Routes.splash, Routes.onboarding};
  if (entryScreens.contains(loc)) return go(Routes.home);
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.otp, builder: (_, _) => const OtpScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),

      // Admin: three tabs with a bottom bar.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.rates, builder: (_, _) => const RatesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.analytics, builder: (_, _) => const AnalyticsScreen()),
          ]),
        ],
      ),
      GoRoute(path: Routes.addAccount, builder: (_, _) => const AddAccountScreen()),
      GoRoute(
        path: '/account/:id',
        builder: (_, s) => AccountScreen(accountId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),

      // Farmer / supplier: read-only screens, no login.
      GoRoute(path: Routes.supplier, builder: (_, _) => const SupplierHomeScreen()),
      GoRoute(
        path: '${Routes.supplier}/account/:id',
        builder: (_, s) => SupplierAccountScreen(accountId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/a/:accountId',
        builder: (_, s) => FollowAccountScreen(accountId: s.pathParameters['accountId']!),
      ),
    ],
  );
});
