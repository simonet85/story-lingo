import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/billing/presentation/book_access_gate.dart';
import '../../features/billing/presentation/paywall_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/reading/presentation/book_entry_screen.dart';
import '../../features/reading/presentation/reading_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../../features/today/presentation/today_screen.dart';
import '../../features/vocabulary/presentation/review_screen.dart';
import '../../features/vocabulary/presentation/word_list_screen.dart';
import '../prefs/user_prefs_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/today',
    redirect: (context, state) {
      final completed = ref.read(userPrefsProvider).onboardingCompleted;
      final atOnboarding = state.matchedLocation == '/onboarding';

      if (!completed) {
        return atOnboarding ? null : '/onboarding';
      }
      if (atOnboarding) {
        return '/today';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/words',
        builder: (context, state) => const WordListScreen(),
      ),
      GoRoute(
        path: '/review',
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => PaywallScreen(
          bookId: state.uri.queryParameters['bookId'],
        ),
      ),
      GoRoute(
        path: '/read/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookAccessGate(
            bookId: bookId,
            child: BookEntryScreen(bookId: bookId),
          );
        },
      ),
      GoRoute(
        path: '/read/:bookId/:chapterId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId']!;
          return BookAccessGate(
            bookId: bookId,
            child: ReadingScreen(
              bookId: bookId,
              chapterId: state.pathParameters['chapterId']!,
            ),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
