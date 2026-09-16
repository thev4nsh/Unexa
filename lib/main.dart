import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/widgets/update_gate.dart';
import 'data/services/firebase_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/security_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/student/providers/student_dashboard_provider.dart';
import 'features/theme/providers/theme_mode_provider.dart';
import 'features/theme/providers/theme_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait-only on phones, both platforms (iPad keeps all orientations —
  // required for full iPad support).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check: blocks non-app clients from Firestore/Storage/Auth.
  // Monitor mode until enforced in the Firebase Console.
  await SecurityService.initialize();
  runApp(const ProviderScope(child: UnexaApp()));
}

class UnexaApp extends ConsumerStatefulWidget {
  const UnexaApp({super.key});

  @override
  ConsumerState<UnexaApp> createState() => _UnexaAppState();
}

class _UnexaAppState extends ConsumerState<UnexaApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationServiceProvider).initialize());
  }

  @override
  Widget build(BuildContext context) {
    // Reactive sync for serverless campus notifications via Firebase Firestore
    ref.listen(currentUserModelProvider, (previous, next) {
      final user = next.value;
      final notifService = ref.read(notificationServiceProvider);
      final firestore = ref.read(firestoreProvider);

      if (user != null && user.collegeId.isNotEmpty) {
        if (user.isPending) {
          notifService.startVerificationStatusSync(
            firestore: firestore,
            collegeId: user.collegeId,
            uid: user.uid,
            onApproved: () => ref.invalidate(currentUserModelProvider),
          );
        } else if (user.isActive && user.isStudent) {
          notifService.startAnnouncementSync(
            firestore: firestore,
            collegeId: user.collegeId,
            departmentId: user.departmentId,
            batchId: user.batchId,
            sectionId: user.sectionId,
          );
          // Notify students when staff publish/replace Routine or Holiday PDFs.
          notifService.startOfficialDocumentSync(
            firestore: firestore,
            collegeId: user.collegeId,
          );
        }
      } else {
        notifService.stopAllSync();
      }
    });

    // Auto-schedule daily 7 AM briefing & 1-hour before class reminders
    // (students only — staff have no class schedule to remind about)
    ref.listen(currentUserModelProvider, (previous, next) {
      final user = next.value;
      if (user != null && user.isActive && user.isStudent) {
        ref.listen(todayClassesProvider, (previous, next) {
          final classes = next.value;
          if (classes != null && classes.isNotEmpty) {
            ref.read(notificationServiceProvider).syncClassReminders(classes);
          }
        });
      }
    });

    final router = ref.watch(appRouterProvider);
    final lightTheme = ref.watch(dynamicLightThemeDataProvider);
    final darkTheme = ref.watch(dynamicDarkThemeDataProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'UNEXA',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      // UpdateGate lives INSIDE MaterialApp (via builder) so the update
      // popup gets Directionality/Theme — wrapping it around MaterialApp
      // crashes with 'No Directionality widget found'.
      builder: (context, child) {
        // Clamp the OS font scale FIRST so it applies to everything below,
        // including UpdateGate: users who crank system text size were getting
        // wrapped/shrunken labels and overflow. Every phone now renders the
        // same layout at the same size.
        final media = MediaQuery.of(context);
        final clamped =
            media.textScaler.clamp(minScaleFactor: 0.95, maxScaleFactor: 1.0);
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: UpdateGate(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
