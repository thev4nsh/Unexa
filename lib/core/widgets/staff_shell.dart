import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/theme/providers/theme_mode_provider.dart';
import 'unexa_card.dart';
import 'unexa_theme_toggle.dart';

/// Shared staff shell for Admin / Co-Admin / Moderator portals.
/// Matches the prototype: Name + "Role - X" header, animated sun toggle,
/// exit button, and a rounded card grid body.
class StaffShell extends ConsumerStatefulWidget {
  final String name;
  final String role;
  final List<Widget> cards;
  final Widget? floatingActionButton;

  const StaffShell({
    super.key,
    required this.name,
    required this.role,
    required this.cards,
    this.floatingActionButton,
  });

  @override
  ConsumerState<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends ConsumerState<StaffShell> {
  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit UNEXA?'),
        content: const Text(
          'You will stay signed in and can reopen the app anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again.'),
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
    // Sun toggle also lives in staff headers, and themeMode is global already.
    ref.watch(themeModeControllerProvider);

    // Fixed, identical tile size on EVERY phone. The app clamps the OS font
    // scale to 1.0 (MaterialApp.builder), so M3 metrics are exact constants:
    // titleMedium renders 24px per line (16sp x 1.5), two lines max.
    // Content: icon 38 + gap 8 + labels 48, padding 16 top & bottom, 8 spare.
    const tileHeight = 16 + 38 + 8 + (2 * 24.0) + 16 + 8;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.name,
              style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Role - ${widget.role}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          const Center(child: ThemeToggleSun(size: 38)),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _confirmLogout,
          ),
          IconButton(
            tooltip: 'Exit',
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: _confirmExit,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentUserModelProvider);
          },
          child: GridView.count(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: tileHeight,
            children: widget.cards,
          ),
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

/// Rounded grid card used on the staff dashboard (prototype style).
class StaffCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  /// Live count shown as a badge on the icon (e.g. pending verifications).
  final int? badgeCount;

  const StaffCard({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    // UnexaCard already applies 16px padding — adding another one here
    // double-padded the tile and squeezed the content area by 32px.
    return UnexaCard(
      onTap: () => context.push(route),
      borderRadius: AppRadius.lg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Badge(
              isLabelVisible: (badgeCount ?? 0) > 0,
              label: Text(
                badgeCount != null && badgeCount! > 99
                    ? '99+'
                    : '${badgeCount ?? 0}',
              ),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            // Ellipsize rather than shrink: the tile height is derived to
            // always fit two lines, so the text never needs to scale down
            // (a FittedBox here made labels unreadably tiny).
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
      ),
    );
  }
}

/// Role helper shared by staff screens.
String staffRoleLabel(String role) {
  switch (role) {
    case AppConstants.roleOwner:
      return 'Admin';
    case AppConstants.roleAdmin:
      return 'Admin';
    case AppConstants.roleCoAdmin:
      return 'Co-Admin';
    case AppConstants.roleModerator:
      return 'Moderator';
    case AppConstants.roleCr:
      return 'CR';
    default:
      return 'Staff';
  }
}
