import 'package:flutter/material.dart';

class UnexaFadeIn extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const UnexaFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay.inMilliseconds),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayedValue = delay == Duration.zero
            ? value
            : ((value * (280 + delay.inMilliseconds) - delay.inMilliseconds) / 280)
                .clamp(0.0, 1.0);

        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - delayedValue)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
