import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';
import 'package:gate_closes/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:gate_closes/features/auth/presentation/pages/login_page.dart';
import 'package:gate_closes/features/auth/presentation/pages/onboarding_page.dart';
import 'package:gate_closes/features/auth/presentation/pages/register_page.dart';
import 'package:gate_closes/features/boarding_pass/presentation/pages/add_boarding_pass_page.dart';
import 'package:gate_closes/features/boarding_pass/presentation/widgets/boarding_pass_scanner_sheet.dart';
import 'package:gate_closes/features/connections/presentation/pages/connections_page.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/features/profile/presentation/pages/change_password_page.dart';
import 'package:gate_closes/features/profile/presentation/pages/profile_editor_page.dart';
import 'package:gate_closes/features/profile/presentation/pages/profile_page.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/airport_search_page.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/create_echo_page.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/echo_thread_loader_page.dart';
import 'package:gate_closes/features/terminal_echo/presentation/pages/feed_page.dart';
import 'package:gate_closes/features/worldMap/presentation/pages/world_map_page.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/main_layout.dart';
import 'package:go_router/go_router.dart';

/// Listenable helper to notify GoRouter whenever auth state changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated) {
          notifyListeners();
        }
      },
    );
  }

  final Ref _ref;
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

/// The app's router. `redirect` guards routes based on auth state; the login
/// form and logout button also navigate explicitly with `context.go(...)`.
final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: RouteNames.home,
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = ref.read(authControllerProvider).user;
      final isAuth = user != null;
      final goingToLogin = state.matchedLocation == RouteNames.login;
      final goingToRegister = state.matchedLocation == RouteNames.register;
      final goingToForgotPassword =
          state.matchedLocation == RouteNames.forgotPassword;
      final goingToPreAuthPage =
          goingToLogin || goingToRegister || goingToForgotPassword;

      if (!isAuth) {
        return goingToPreAuthPage ? null : RouteNames.login;
      }

      // Onboarding gate: new users see it once.
      final seenOnboarding =
          ref.read(storageServiceProvider).isOnboardingSeen(user.id);
      if (!seenOnboarding) {
        final goingToOnboarding =
            state.matchedLocation == RouteNames.onboarding;
        return goingToOnboarding ? null : RouteNames.onboarding;
      }

      // Reaching here while authenticated and still on a pre-auth page means
      // the forgot-password wizard just logged the user in — bounce home.
      if (goingToPreAuthPage) return RouteNames.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => OnboardingPage(
          boardingPassStep: (onCompleted) => BoardingPassScannerSheet(
            completeButtonText: 'COMPLETE ONBOARDING',
            onCompleted: onCompleted,
          ),
        ),
      ),
      GoRoute(
        path: RouteNames.createEcho,
        builder: (context, state) => const CreateEchoPage(),
      ),
      GoRoute(
        path: RouteNames.echoThread,
        builder: (context, state) {
          final extra = state.extra;
          return EchoThreadLoaderPage(
            echoId: state.pathParameters['echoId']!,
            initialEcho: extra is TerminalEchoEntity ? extra : null,
          );
        },
      ),
      GoRoute(
        path: RouteNames.airportSearch,
        builder: (context, state) => const AirportSearchPage(),
      ),
      GoRoute(
        path: RouteNames.addBoardingPass,
        builder: (context, state) {
          final extra = state.extra;
          final ticket = extra is FlightTicketEntity ? extra : null;
          return AddBoardingPassPage(initialTicket: ticket);
        },
      ),
      GoRoute(
        path: RouteNames.editProfile,
        builder: (context, state) => const ProfileEditorPage(),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (context, state) => const ConnectionsPage(),
          ),
          GoRoute(
            path: RouteNames.worldMap,
            builder: (context, state) => const WorldMapPage(),
          ),
          GoRoute(
            path: RouteNames.feed,
            builder: (context, state) => const FeedPage(),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});
