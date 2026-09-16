import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check — blocks non-app clients (scripts, modified binaries,
/// raw REST hits) from using this project's Firestore/Storage backends.
///
/// Providers:
///   Android  -> Play Integrity (hardware-backed attestation via Google Play)
///   iOS      -> App Attest with Device Check fallback (iOS 14+ / older devices)
///   debug    -> debug providers so emulators/dev builds keep working
///
/// Enforcement is controlled in the Firebase Console:
/// start in MONITOR mode (log-only), then flip Firestore/Storage to ENFORCED
/// once you see only legitimate traffic.
class SecurityService {
  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        // Debug providers keep emulators and local dev usable.
        // Register the debug token printed in the console under
        // Firebase Console -> App Check -> Apps -> Manage debug tokens.
        await FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidDebugProvider(),
          providerApple: AppleDebugProvider(),
        );
        debugPrint(
            '[AppCheck] DEBUG providers active — register the debug token in the console.');
        return;
      }

      if (Platform.isIOS || Platform.isMacOS) {
        // App Attest (Secure Enclave) with automatic Device Check fallback
        // for devices below iOS 14.
        await FirebaseAppCheck.instance.activate(
          providerApple: AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: AndroidPlayIntegrityProvider(),
        );
      }
    } catch (e) {
      // Never crash the app over attestation — App Check fails open until the
      // console enforces it, and offline/first-run hiccups must not brick UX.
      debugPrint('[AppCheck] activation issue (app continues): $e');
    }
  }
}
