import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';

/// AppBar with a working back button for staff sub-screens.
///
/// Staff screens are reached with go_router `go()`, which replaces the
/// navigation stack — Flutter's automatic back button never appears because
/// there is nothing to pop. This AppBar always shows an explicit back arrow
/// that routes to the viewer's role home:
/// moderator -> /moderator/home, every other staff role -> /admin/dashboard.
class StaffBackAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;

  const StaffBackAppBar({super.key, required this.title, this.bottom});

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).value;
    final homeRoute = user == null
        ? '/admin/dashboard'
        : user.isCr
            ? '/moderator/home'
            : user.isModerator
                ? '/moderator/dashboard'
                : '/admin/dashboard';

    return AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Back',
        onPressed: () => context.go(homeRoute),
      ),
      bottom: bottom,
    );
  }
}
