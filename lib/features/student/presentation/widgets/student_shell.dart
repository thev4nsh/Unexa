import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';

class StudentShell extends ConsumerStatefulWidget {
  // Students see only Home + Profile; every other section lives on the home
  // screen itself. Moderators reuse this shell with their own routes.
  static const _studentItems = [
    _NavItem('/student/home', Icons.home_rounded, 'Home'),
    _NavItem('/student/profile', Icons.person_rounded, 'Profile'),
  ];

  static const _moderatorItems = [
    _NavItem('/moderator/home', Icons.home_rounded, 'Home'),
    _NavItem('/moderator/profile', Icons.person_rounded, 'Profile'),
  ];

  final String title;
  final String? subtitle;
  final String currentRoute;
  final Widget child;
  final List<Widget>? actions;
  final bool showBackButton;

  /// When true the shell routes to /moderator/home and /moderator/profile —
  /// used by the staff home that mirrors the student front page.
  final bool moderatorMode;

  const StudentShell({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.child,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
    this.moderatorMode = false,
  });

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again with Google.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = widget.currentRoute;
    final items = widget.moderatorMode
        ? StudentShell._moderatorItems
        : StudentShell._studentItems;
    final selectedIndex = items.indexWhere((item) => item.route == currentRoute);
    final visibleIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title.isEmpty ? AppConstants.appName : widget.title,
              style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                    fontSize: widget.subtitle == null ? 18 : 15,
                  ),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          ],
        ),
        actions: [
          ...(widget.actions ?? const []),
          if (currentRoute == items.last.route)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: _confirmLogout,
            ),
        ],
      ),
      body: SafeArea(child: widget.child),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: visibleIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: (index) {
          final target = items[index].route;
          if (target != currentRoute) context.go(target);
        },
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Tooltip(
                  message: item.label,
                  child: Icon(item.icon),
                ),
                selectedIcon: Tooltip(
                  message: item.label,
                  child: Icon(item.icon),
                ),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;

  const _NavItem(this.route, this.icon, this.label);
}

class StudentPagePadding extends StatelessWidget {
  final Widget child;

  const StudentPagePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
  }
}
