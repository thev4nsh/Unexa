import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/ban_model.dart';
import '../../../data/models/verification_request_model.dart';
import '../../../data/repositories/verification_repository.dart';
import '../../auth/providers/auth_provider.dart';

class VerificationStatusTabNotifier extends Notifier<String> {
  @override
  String build() => 'pending';
  void setTab(String tab) => state = tab;
}

final verificationStatusTabProvider =
    NotifierProvider<VerificationStatusTabNotifier, String>(VerificationStatusTabNotifier.new);

class VerificationSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final verificationSearchQueryProvider =
    NotifierProvider<VerificationSearchQueryNotifier, String>(VerificationSearchQueryNotifier.new);

class VerificationDeptFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setFilter(String? dept) => state = dept;
}

final verificationDeptFilterProvider =
    NotifierProvider<VerificationDeptFilterNotifier, String?>(VerificationDeptFilterNotifier.new);

class VerificationBatchFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setFilter(String? batch) => state = batch;
}

final verificationBatchFilterProvider =
    NotifierProvider<VerificationBatchFilterNotifier, String?>(VerificationBatchFilterNotifier.new);

class VerificationRoleFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setFilter(String? role) => state = role;
}

final verificationRoleFilterProvider =
    NotifierProvider<VerificationRoleFilterNotifier, String?>(VerificationRoleFilterNotifier.new);

/// Live uid -> role map, used by the All Users tab to show role chips and
/// filter by role.
final userRolesMapProvider =
    StreamProvider.autoDispose.family<Map<String, String>, String>((ref, collegeId) {
  return ref.watch(verificationRepositoryProvider).streamUserRoles(collegeId);
});

/// Authoritative stream of raw verification requests by college and status
final verificationRequestsStreamProvider =
    StreamProvider.family<List<VerificationRequestModel>, (String, String?)>((ref, args) {
  final (collegeId, status) = args;
  return ref.watch(verificationRepositoryProvider).streamRequests(collegeId, status: status);
});

/// Filtered verification requests stream
final filteredVerificationRequestsProvider = Provider<AsyncValue<List<VerificationRequestModel>>>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) {
    return const AsyncValue.data([]);
  }

  final statusTab = ref.watch(verificationStatusTabProvider);
  final searchQuery = ref.watch(verificationSearchQueryProvider).trim().toLowerCase();
  final deptFilter = ref.watch(verificationDeptFilterProvider);
  final batchFilter = ref.watch(verificationBatchFilterProvider);
  final roleFilter = ref.watch(verificationRoleFilterProvider);
  final userRoles = ref.watch(userRolesMapProvider(user.collegeId)).value ?? const {};

  // 'all' streams every request regardless of status — the All Users tab.
  final rawRequestsAsync = ref.watch(
    verificationRequestsStreamProvider((user.collegeId, statusTab == 'all' ? null : statusTab)),
  );

  final existingUserIdsAsync =
      ref.watch(existingUserIdsProvider(user.collegeId));

  return rawRequestsAsync.whenData((requests) {
    // Users deleted from Firebase vanish from every admin list in real time.
    final existingUserIds = existingUserIdsAsync.value ?? const <String>{};
    return requests.where((req) {
      if (existingUserIds.isNotEmpty && !existingUserIds.contains(req.uid)) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final matchesName = req.displayName.toLowerCase().contains(searchQuery);
        final matchesEmail = req.email.toLowerCase().contains(searchQuery);
        if (!matchesName && !matchesEmail) return false;
      }
      if (deptFilter != null && deptFilter.isNotEmpty) {
        if (req.departmentName != deptFilter) return false;
      }
      if (batchFilter != null && batchFilter.isNotEmpty) {
        if (req.batchName != batchFilter) return false;
      }
      if (roleFilter != null && roleFilter.isNotEmpty) {
        if ((userRoles[req.uid] ?? 'student') != roleFilter) return false;
      }
      return true;
    }).toList();
  });
});

/// Live set of uids with an existing college user document.
final existingUserIdsProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, collegeId) {
  return ref.watch(verificationRepositoryProvider).streamExistingUserIds(collegeId);
});

/// Verification Action Controller
class VerificationController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> approveStudent(String targetUid) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.approveStudent(collegeId: actor.collegeId, targetUid: targetUid, actor: actor);
    });
  }

  Future<void> rejectStudent(String targetUid, String reason) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.rejectStudent(collegeId: actor.collegeId, targetUid: targetUid, actor: actor, reason: reason);
    });
  }

  Future<void> banStudent(String targetUid, String reason) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.banStudent(collegeId: actor.collegeId, targetUid: targetUid, actor: actor, reason: reason);
    });
  }

  /// Disapprove an approved student/staff: back to the pending queue,
  /// academics kept, fully audit-logged. Admin/Co-Admin only.
  Future<void> disapproveStudent(String targetUid, String reason) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null || !actor.canManageRoles) {
      throw StateError('Only Admins and Co-Admins can disapprove an approved member.');
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.disapproveStudent(
        collegeId: actor.collegeId,
        targetUid: targetUid,
        actor: actor,
        reason: reason,
      );
    });
  }

  Future<void> unbanStudent(String targetUid, BanModel currentBan, String reason) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.unbanStudent(
        collegeId: actor.collegeId,
        targetUid: targetUid,
        actor: actor,
        currentBan: currentBan,
        reason: reason,
      );
    });
  }

  /// Remove a user completely: deletes user doc, verification request and
  /// global index in one atomic write. They must re-register from zero.
  Future<void> removeUserCompletely(String targetUid, String reason) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.removeUserCompletely(
        collegeId: actor.collegeId,
        targetUid: targetUid,
        actor: actor,
        reason: reason,
      );
    });
  }

  Future<void> unbanStudentFromProfile(String targetUid, String reason) async {
    final actor = ref.read(currentUserModelProvider).value;
    if (actor == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(verificationRepositoryProvider);
      final target = await repo.getUser(actor.collegeId, targetUid);
      final currentBan = target?.banDetails;
      if (target == null || currentBan == null || !currentBan.isActive) {
        throw StateError('This account is not currently banned.');
      }
      await repo.unbanStudent(
        collegeId: actor.collegeId,
        targetUid: targetUid,
        actor: actor,
        currentBan: currentBan,
        reason: reason,
      );
    });
  }
}

final verificationControllerProvider =
    AsyncNotifierProvider<VerificationController, void>(VerificationController.new);
