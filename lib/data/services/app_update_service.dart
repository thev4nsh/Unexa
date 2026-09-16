import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/firestore_paths.dart';
import '../models/app_config_model.dart';

/// Realtime in-app update system.
///
/// Firestore (global, institute-independent):
///   config/appUpdate -> {latestVersion, minVersion, apkUrl / apkStoragePath,
///                        storeUrl, releaseNotes, enabled}
///
/// The APK can be given either as:
///   - a direct https download URL (any host), or
///   - a Firebase Storage path ("updates/app.apk" or "gs://bucket/updates/app.apk")
///     which is resolved to a fresh download URL with the user's session.
class AppUpdateService {
  static const _apkFileName = 'unexa-update.apk';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AppUpdateService(this._firestore, this._storage);

  /// Live config stream — one global doc.
  Stream<AppConfigModel?> streamConfig() {
    return _firestore.doc(FirestorePaths.appUpdateConfigPath).snapshots().map(
          (snap) =>
              snap.exists ? AppConfigModel.fromMap(snap.data() ?? {}) : null,
        );
  }

  /// This build's version string from pubspec (via package_info_plus).
  static Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Resolve whatever the config holds into a downloadable https URL.
  Future<String> resolveApkUrl(AppConfigModel config) async {
    final storagePath = config.apkStoragePath;
    if (storagePath != null && storagePath.trim().isNotEmpty) {
      return await _resolveStorageRef(storagePath.trim());
    }

    final raw = (config.apkUrl ?? '').trim();
    if (raw.isEmpty) {
      throw const AppUpdateException(
          'No update file is configured yet (apkUrl is empty).');
    }

    // gs://bucket/path -> strip scheme, resolve through Storage.
    if (raw.startsWith('gs://')) {
      return await _resolveStorageRef(raw.substring('gs://'.length));
    }

    // Firebase Storage https browser link
    // (.../o/<encoded path>?alt=media&token=...) -> resolve via Storage so
    // revoked/expired tokens always get a fresh URL.
    final bucket = RegExp(r'https://firebasestorage\.googleapis\.com/v0/b/([^/]+)/o/(.*)');
    final m = bucket.firstMatch(raw);
    if (m != null) {
      final path = Uri.decodeComponent(m.group(2)!.split('?').first);
      return await _resolveStorageRef(path, bucketOverride: m.group(1));
    }

    if (!raw.startsWith('http')) {
      // Bare Storage path like "updates/app.apk".
      return await _resolveStorageRef(raw);
    }

    return raw; // direct https URL from any host
  }

  Future<String> _resolveStorageRef(String path, {String? bucketOverride}) async {
    try {
      final ref = bucketOverride == null
          ? _storage.ref(path)
          : FirebaseStorage.instanceFor(bucket: 'gs://$bucketOverride').ref(path);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        throw AppUpdateException(
            'Update file not found in Storage at "$path". Upload the APK and check the path.');
    }
      if (e.code.contains('unauthorized') || e.code == 'unauthorized') {
        throw AppUpdateException(
            'Storage rules denied the download. Allow signed-in users to read the updates/ folder.');
      }
      rethrow;
    }
  }

  /// Download the APK and hand it to the Android package installer.
  /// Progress is reported 0.0 -> 1.0 for the UI.
  Future<void> downloadAndInstall({
    required AppConfigModel config,
    required void Function(double progress) onProgress,
  }) async {
    final url = await resolveApkUrl(config);

    final dir = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final savePath = '${dir.path}/$_apkFileName';

    // Fresh download every attempt (no partial-file resume bugs).
    final file = File(savePath);
    if (await file.exists()) await file.delete();

    try {
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 15),
          headers: {'Cache-Control': 'no-cache'},
        ),
      );
    } on DioException catch (e) {
      throw AppUpdateException(_dioMessage(e));
    }

    // Hand off to the Android package installer (user confirms "Install";
    // the app is replaced in place — no uninstall, all data preserved).
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        throw AppUpdateException(
            'Could not open the installer: ${result.message}. If Android asks, allow "Install unknown apps" for UNEXA.');
      }
    } else if (kDebugMode) {
      debugPrint('[Update] install not supported on this platform: $savePath');
    }
  }

  String _dioMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return 'Could not reach the update server. Check your internet.';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Download timed out. Try again on a stronger connection.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 403 || code == 401) {
          return 'The update link was rejected (403). Re-copy the download URL from Firebase Storage.';
        }
        if (code == 404) {
          return 'Update file missing at the server (404). Check the apkUrl.';
        }
        return 'Server error $code while downloading.';
      default:
        return 'Download failed: ${e.message ?? 'unknown error'}';
    }
  }

  /// Open the store listing (or any URL) when no direct APK is configured.
  Future<bool> openStore(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

/// User-facing update failure with a specific, actionable message.
class AppUpdateException implements Exception {
  final String message;
  const AppUpdateException(this.message);

  @override
  String toString() => message;
}
