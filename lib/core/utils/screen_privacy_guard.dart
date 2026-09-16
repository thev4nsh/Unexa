import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks screenshots and app-switch previews on sensitive screens.
///
/// Android: a MethodChannel tells MainActivity to set/clear WindowManager
/// FLAG_SECURE (see android/app/src/main/kotlin/.../MainActivity.kt).
/// iOS:     Apple provides no public API to block screenshots/recording —
///          this is an OS restriction, so the wrapper is a no-op there.
class SecureScreen extends StatefulWidget {
  final Widget child;

  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static const _channel = MethodChannel('unexa/security');

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _setSecure(true);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _setSecure(false);
    }
    super.dispose();
  }

  Future<void> _setSecure(bool on) async {
    try {
      await _channel.invokeMethod('setSecure', {'on': on});
    } on MissingPluginException {
      // Native handler absent (web/desktop tests) — ignore.
    } catch (_) {
      // Best-effort privacy guard; never crash over it.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
