import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/verification_pending_screen.dart';
import '../../features/student/presentation/onboarding_screen.dart';
import '../../features/student/presentation/student_dashboard_screen.dart';
import '../../features/student/presentation/student_timetable_screen.dart';
import '../../features/student/presentation/student_announcements_screen.dart';
import '../../features/student/presentation/student_calendar_screen.dart';
import '../../features/student/presentation/student_documents_screen.dart';
import '../../features/student/presentation/student_profile_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_academics_screen.dart';
import '../../features/admin/presentation/admin_faculties_screen.dart';
import '../../features/admin/presentation/admin_announcements_screen.dart';
import '../../features/admin/presentation/admin_calendar_screen.dart';
import '../../features/admin/presentation/admin_documents_screen.dart';
import '../../features/admin/presentation/admin_timetable_screen.dart';
import '../../features/admin/presentation/admin_moderators_screen.dart';
import '../../features/admin/presentation/audit_log_screen.dart';
import '../../features/moderator/presentation/moderator_home_screen.dart';
import '../../features/moderator/presentation/moderator_profile_screen.dart';
import '../../features/admin/presentation/verification_requests_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(userCollegeIdProvider, (_, _) => notifyListeners());
    _ref.listen(currentUserModelProvider, (_, _) => notifyListeners());
    // Re-run routing when the student's class target existence changes —
    // this is what pulls students back to onboarding the moment an admin
    // deletes their batch or department.
    _ref.listen(classTargetExistsProvider, (_, _) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
    final authState = ref.read(authStateProvider);
    final collegeIdLookup = ref.read(userCollegeIdProvider);
    final userModel = ref.read(currentUserModelProvider);
    final classTarget = ref.read(classTargetExistsProvider);

    final isLoggedIn = authState.value != null;
    final user = userModel.value;
    final isLoading =
        authState.isLoading ||
        collegeIdLookup.isLoading ||
        userModel.isLoading ||
        classTarget.isLoading;
      if (isLoading) return null;

      final isOnLogin = state.matchedLocation == '/';
      final isOnPending = state.matchedLocation == '/verification-pending';
      final isOnOnboarding = state.matchedLocation == '/onboarding';
      final isStudentRoute = state.matchedLocation.startsWith('/student');
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isModRoute = state.matchedLocation.startsWith('/moderator');

      if (!isLoggedIn) return isOnLogin ? null : '/';
      if (user == null || user.isPending || user.isRejected || user.isBanned) {
        return isOnPending ? null : '/verification-pending';
      }

      if (user.isActive) {
        // Students and CRs both need onboarding — the CR's class is part of
        // their role.
        if ((user.isStudent || user.isCr) && !user.isOnboardingComplete) {
          return isOnOnboarding ? null : '/onboarding';
        }
        // Deleted-class guard: if an admin removed this student's department
        // or batch, send them back to onboarding to pick fresh academic
        // details — dangling class data must never strand a student or CR.
        if ((user.isStudent || user.isCr) &&
            user.isOnboardingComplete &&
            classTarget.value == false) {
          return isOnOnboarding ? null : '/onboarding';
        }
        // Staff route guard: only admin-and-above may open /admin/* except
        // the verification screen, which moderators/CRs also use.
        final isVerificationRoute =
            state.matchedLocation == '/admin/verification';
        if (user.isModeratorKind && isAdminRoute && !isVerificationRoute) {
          return user.isCr ? '/moderator/home' : '/moderator/dashboard';
        }
        if (user.isStudent && (isAdminRoute || isModRoute)) {
          return '/student/home';
        }
        // Pure moderators stay on staff routes; CRs keep the student front end.
        if (user.isModerator && isStudentRoute) return '/moderator/dashboard';
        // Role-switch live moves: a student promoted to CR (or a Mod promoted
        // to CR) is sent to the CR home — the student layout with the one
        // extra Verification card. Without this they'd stay stranded on their
        // old screen until app restart.
        if (user.isCr && (isStudentRoute || state.matchedLocation == '/moderator/dashboard')) {
          return '/moderator/home';
        }
        // A CR demoted to pure Mod leaves the CR home immediately — no
        // student cards for staff-only accounts.
        if (user.isModerator && state.matchedLocation == '/moderator/home') {
          return '/moderator/dashboard';
        }
        if (user.isStaff &&
            !user.isModeratorKind &&
            (isStudentRoute || isModRoute)) {
          return '/admin/dashboard';
        }
        if (isOnLogin || isOnPending || isOnOnboarding) {
          if (user.isCr) return '/moderator/home';
          if (user.isModerator) return '/moderator/dashboard';
          return user.isStaff ? '/admin/dashboard' : '/student/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LoginScreen()),
      GoRoute(
        path: '/verification-pending',
        builder: (c, s) => const VerificationPendingScreen(),
      ),
      GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(
        path: '/moderator/home',
        builder: (c, s) => const ModeratorHomeScreen(),
      ),
      GoRoute(
        path: '/moderator/dashboard',
        builder: (c, s) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/moderator/profile',
        builder: (c, s) => const ModeratorProfileScreen(),
      ),

      // Student Routes
      GoRoute(
        path: '/student/home',
        builder: (c, s) => const StudentDashboardScreen(),
      ),
      GoRoute(
        path: '/student/timetable',
        builder: (c, s) => const StudentTimetableScreen(),
      ),
      GoRoute(
        path: '/student/announcements',
        builder: (c, s) => const StudentAnnouncementsScreen(),
      ),
      GoRoute(
        path: '/student/calendar',
        builder: (c, s) => const StudentCalendarScreen(),
      ),
      GoRoute(
        path: '/student/documents',
        builder: (c, s) => const StudentDocumentsScreen(),
      ),
      GoRoute(
        path: '/student/profile',
        builder: (c, s) => const StudentProfileScreen(),
      ),

      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (c, s) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/verification',
        builder: (c, s) => const VerificationRequestsScreen(),
      ),
      GoRoute(
        path: '/admin/academics',
        builder: (c, s) => const AdminAcademicsScreen(),
      ),
      GoRoute(
        path: '/admin/timetable',
        builder: (c, s) => const AdminTimetableScreen(),
      ),
      GoRoute(
        path: '/admin/faculties',
        builder: (c, s) => const AdminFacultiesScreen(),
      ),
      GoRoute(
        path: '/admin/announcements',
        builder: (c, s) => const AdminAnnouncementsScreen(),
      ),
      GoRoute(
        path: '/admin/calendar',
        builder: (c, s) => const AdminCalendarScreen(),
      ),
      GoRoute(
        path: '/admin/documents',
        builder: (c, s) => const AdminDocumentsScreen(),
      ),
      GoRoute(
        path: '/admin/moderators',
        builder: (c, s) => const AdminModeratorsScreen(),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (c, s) => const AuditLogScreen(),
      ),
    ],
  );
});
