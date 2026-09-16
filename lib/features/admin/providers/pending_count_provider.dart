import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/verification_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Live count of pending verification requests for the signed-in staff's
/// institute — drives the badge on Verification cards and dashboard tiles.
final pendingVerificationCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserModelProvider).value;
  if (user == null || user.collegeId.isEmpty) return Stream.value(0);

  return ref
      .watch(verificationRepositoryProvider)
      .streamRequests(user.collegeId, status: 'pending')
      .map((requests) => requests.length);
});
