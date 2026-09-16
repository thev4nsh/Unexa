import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_config_model.dart';
import '../../data/services/app_update_service.dart';
import '../../data/services/firebase_service.dart';
import 'unexa_card.dart';
import '../theme/app_theme.dart';

/// Providers
final appUpdateServiceProvider = Provider<AppUpdateService>(
    (ref) => AppUpdateService(
        ref.watch(firestoreProvider), ref.watch(firebaseStorageProvider)));

final currentAppVersionProvider = FutureProvider<String>(
    (ref) => AppUpdateService.currentVersion());

final appUpdateConfigProvider = StreamProvider<AppConfigModel?>(
    (ref) => ref.watch(appUpdateServiceProvider).streamConfig());

/// Download state for the in-app install button.
class UpdateDownloadState {
  final bool downloading;
  final double progress;
  final String? error;

  const UpdateDownloadState({
    this.downloading = false,
    this.progress = 0,
    this.error,
  });
}

class UpdateDownloadNotifier extends Notifier<UpdateDownloadState> {
  @override
  UpdateDownloadState build() => const UpdateDownloadState();

  Future<void> start(AppConfigModel config) async {
    state = const UpdateDownloadState(downloading: true);
    try {
      await ref.read(appUpdateServiceProvider).downloadAndInstall(
            config: config,
            onProgress: (p) =>
                state = UpdateDownloadState(downloading: true, progress: p),
          );
      // Installer takes over; leave progress at 100% behind it.
      state = const UpdateDownloadState(downloading: false, progress: 1);
    } on AppUpdateException catch (e) {
      state = UpdateDownloadState(error: e.message);
    } catch (e) {
      state = UpdateDownloadState(
          error: 'Update failed: $e');
    }
  }

  void reset() => state = const UpdateDownloadState();
}

final updateDownloadProvider =
    NotifierProvider<UpdateDownloadNotifier, UpdateDownloadState>(
        UpdateDownloadNotifier.new);

/// Wrap the app (or home scaffold) with this gate. When the streamed config
/// declares a newer version, a live popup appears — realtime, no restart.
/// Below [minVersion] the popup cannot be dismissed.
class UpdateGate extends ConsumerWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Updates only apply to Android; iOS updates go through the App Store.
    if (!Platform.isAndroid) return child;

    final configAsync = ref.watch(appUpdateConfigProvider);
    final versionAsync = ref.watch(currentAppVersionProvider);

    final config = configAsync.value;
    final current = versionAsync.value;
    final dismissedVersion = ref.watch(updateDismissedVersionProvider);

    // Not loaded yet / disabled / up to date / skipped this session -> hide.
    final showUpdate = config != null &&
        config.enabled &&
        current != null &&
        config.isUpdateAvailableFor(current) &&
        dismissedVersion != config.latestVersion;

    if (!showUpdate) return child;

    final forced = config.isForcedFor(current);
    if (forced) {
      return Stack(
        children: [
          ExcludeSemantics(child: IgnorePointer(child: child)),
          _UpdateOverlay(config: config, forced: true),
        ],
      );
    }

    return Stack(
      children: [
        child,
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _UpdateCard(config: config),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpdateOverlay extends StatelessWidget {
  final AppConfigModel config;
  final bool forced;

  const _UpdateOverlay({required this.config, required this.forced});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _UpdateCard(config: config, forced: forced),
        ),
      ),
    );
  }
}

class _UpdateCard extends ConsumerWidget {
  final AppConfigModel config;
  final bool forced;

  const _UpdateCard({required this.config, this.forced = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final download = ref.watch(updateDownloadProvider);
    final current = ref.watch(currentAppVersionProvider).value ?? '?';

    return UnexaCard(
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Icon(Icons.system_update_rounded,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forced ? 'Update required' : 'Update available',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'v$current → v${config.latestVersion}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (config.releaseNotes?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                config.releaseNotes!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (download.error != null) ...[
              Text(
                download.error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (download.downloading) ...[
              LinearProgressIndicator(value: download.progress, minHeight: 6),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Downloading… ${(download.progress * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ] else
              FilledButton.icon(
                onPressed: () {
                  final hasApk = (config.apkStoragePath?.isNotEmpty ?? false) ||
                      (config.apkUrl?.isNotEmpty ?? false);
                  if (hasApk) {
                    ref.read(updateDownloadProvider.notifier).start(config);
                  } else if (config.storeUrl?.isNotEmpty ?? false) {
                    ref.read(appUpdateServiceProvider).openStore(config.storeUrl!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Update link not configured yet — set apkUrl in config/appUpdate.')));
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: Text(
                    ((config.apkStoragePath?.isNotEmpty ?? false) ||
                            (config.apkUrl?.isNotEmpty ?? false))
                        ? 'Update now'
                        : 'Open store',
                ),
              ),
            if (!forced && !download.downloading)
              TextButton(
                onPressed: () {
                  ref.read(updateDownloadProvider.notifier).reset();
                  // Dismiss for this session by disabling the popup source —
                  // the simplest reliable way: remember the offered version.
                  _skipVersion(context, config.latestVersion);
                },
                child: const Text('Later'),
              ),
          ],
        ),
      ),
    );
  }

  void _skipVersion(BuildContext context, String version) {
    // Session-level skip: hide the card until app restart.
    // (Forced updates below minVersion never offer this button.)
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(updateDismissedVersionProvider.notifier).dismiss(version);
  }
}

/// Session-scoped "Later" memory.
class UpdateDismissedVersionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void dismiss(String v) => state = v;
}

final updateDismissedVersionProvider =
    NotifierProvider<UpdateDismissedVersionNotifier, String?>(
        UpdateDismissedVersionNotifier.new);
