/// Live app-update config stored in Firestore:
///   config/appUpdate -> {
///     latestVersion: "1.1.0",      // must match pubspec version format
///     minVersion:     "1.0.0",     // below this = FORCED update (no skip)
///     apkUrl:         "https://firebasestorage.googleapis.com/...",  // direct in-app install
///     storeUrl:       "https://play.google.com/store/apps/details?id=com.unexa.app", // optional fallback
///     releaseNotes:   "What's new in this version...",
///     enabled:        true
///   }
class AppConfigModel {
  final String latestVersion;
  final String? minVersion;

  /// Direct https download URL — OR a Firebase Storage path like
  /// "updates/unexa-1.1.0.apk" or "gs://bucket/updates/unexa-1.1.0.apk".
  /// gs:// and bare Storage paths are resolved automatically at download time.
  final String? apkUrl;

  /// Optional: Storage path when you prefer a separate field from apkUrl.
  final String? apkStoragePath;
  final String? storeUrl;
  final String? releaseNotes;
  final bool enabled;

  const AppConfigModel({
    required this.latestVersion,
    this.minVersion,
    this.apkUrl,
    this.apkStoragePath,
    this.storeUrl,
    this.releaseNotes,
    this.enabled = true,
  });

  factory AppConfigModel.fromMap(Map<String, dynamic> data) {
    return AppConfigModel(
      latestVersion: data['latestVersion'] as String? ?? '1.0.0',
      minVersion: data['minVersion'] as String?,
      apkUrl: data['apkUrl'] as String?,
      apkStoragePath: data['apkStoragePath'] as String?,
      storeUrl: data['storeUrl'] as String?,
      releaseNotes: data['releaseNotes'] as String?,
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  /// True when the running [current] version is below [minVersion]
  /// (or minVersion is unset and latest > current, if forced via UI).
  bool isForcedFor(String current) {
    final min = minVersion;
    if (min == null || min.isEmpty) return false;
    return _compareVersions(current, min) < 0;
  }

  bool isUpdateAvailableFor(String current) {
    return _compareVersions(current, latestVersion) < 0;
  }
}

/// Compare dotted version strings: -1 when a < b, 0 when equal, 1 when a > b.
/// Handles "1.2.3", "1.2.3+7" (build number ignored) and differing lengths.
int _compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();

  final pa = parse(a);
  final pb = parse(b);
  final len = pa.length > pb.length ? pa.length : pb.length;

  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va < vb) return -1;
    if (va > vb) return 1;
  }
  return 0;
}
