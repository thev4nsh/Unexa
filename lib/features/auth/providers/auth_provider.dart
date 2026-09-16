import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/college_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/verification_request_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/academic_repository.dart';
import '../../../data/repositories/college_repository.dart';
import '../../../data/repositories/verification_repository.dart';
import '../../../data/services/notification_service.dart';

/// Candidate college selected on login screen
class SelectedCandidateCollegeNotifier extends Notifier<CollegeModel?> {
  @override
  CollegeModel? build() => null;

  void select(CollegeModel? college) {
    state = college;
  }
}

final selectedCandidateCollegeProvider =
    NotifierProvider<SelectedCandidateCollegeNotifier, CollegeModel?>(SelectedCandidateCollegeNotifier.new);

/// Firebase Auth State Stream
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Current User College ID lookup
final userCollegeIdProvider = FutureProvider<String?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;
  return ref.watch(authRepositoryProvider).lookupUserCollegeId(authUser.uid);
});

/// The user's own verification request — carries who rejected/banned/
/// disapproved them, when, and the exact reason typed by staff.
final ownVerificationRequestProvider =
    StreamProvider<VerificationRequestModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  final collegeId = ref.watch(userCollegeIdProvider).value;

  if (authUser == null || collegeId == null || collegeId.isEmpty) {
    return Stream.value(null);
  }
  return ref
      .watch(verificationRepositoryProvider)
      .streamOwnRequest(collegeId, authUser.uid);
});

/// Authoritative Current UserModel Stream
final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  final collegeId = ref.watch(userCollegeIdProvider).value;

  if (authUser == null || collegeId == null || collegeId.isEmpty) {
    return Stream.value(null);
  }

  return ref.watch(authRepositoryProvider).streamUser(collegeId, authUser.uid);
});

/// Live check that the student's onboarding class target still exists.
/// When an admin deletes the student's DEPARTMENT or BATCH, this flips to
/// false and the router sends the student back to onboarding to pick again.
/// A synthetic common batch ('') always exists by definition.
final classTargetExistsProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return true;
  if (!user.isStudent && !user.isCr) return true;
  if (!user.isOnboardingComplete) return true; // router handles this separately
  final departmentId = user.departmentId!;
  final batchId = user.batchId!;

  try {
    final depts = await ref.watch(departmentsProvider(user.collegeId).future);
    if (!depts.any((d) => d.id == departmentId)) return false;
    if (batchId.isNotEmpty) {
      final batches = await ref
          .watch(batchesProvider((user.collegeId, departmentId)).future);
      if (!batches.any((b) => b.id == batchId)) return false;
    }
  } catch (_) {
    // A transient network/error must never trap students in onboarding.
    return true;
  }
  return true;
});

/// Authoritative Current CollegeModel Stream (for dynamic branding and schedules)
final currentCollegeModelProvider = StreamProvider<CollegeModel?>((ref) {
  final collegeId = ref.watch(userCollegeIdProvider).value;
  if (collegeId == null || collegeId.isEmpty) {
    final candidate = ref.watch(selectedCandidateCollegeProvider);
    return Stream.value(candidate);
  }

  return ref.watch(collegeRepositoryProvider).streamCollege(collegeId);
});

/// AuthController for login, onboarding, and logout
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle(CollegeModel selectedCollege) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepo = ref.read(authRepositoryProvider);
      final notifService = ref.read(notificationServiceProvider);
      await authRepo.signInWithGoogle(selectedCollege: selectedCollege);

      await notifService.requestPermission();
      ref.invalidate(userCollegeIdProvider);
    });
  }

  Future<void> completeOnboarding({
    required String collegeId,
    required String uid,
    required String departmentId,
    required String departmentName,
    required String batchId,
    required String batchName,
    int? year,
    String? sectionId,
    String? sectionName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.completeOnboarding(
        collegeId: collegeId,
        uid: uid,
        departmentId: departmentId,
        departmentName: departmentName,
        batchId: batchId,
        batchName: batchName,
        year: year,
        sectionId: sectionId,
        sectionName: sectionName,
      );
      ref.invalidate(currentUserModelProvider);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signOut();
      ref.invalidate(userCollegeIdProvider);
      ref.read(selectedCandidateCollegeProvider.notifier).select(null);
    });
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
