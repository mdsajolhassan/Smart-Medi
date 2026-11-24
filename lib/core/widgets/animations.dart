import 'package:flutter/material.dart';

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Fades and slides its child up into place once, staggered by [index]
/// so lists cascade in.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 420),
    this.offsetY = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return child;
    // Cap the stagger so long lists don't wait forever.
    final delayFraction = (index.clamp(0, 8)) * 0.06;
    final total = duration + Duration(milliseconds: (duration.inMilliseconds * delayFraction * 2).round());
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delayFraction.clamp(0.0, 0.6), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offsetY), child: child),
      ),
    );
  }
}

/// Pulses a glowing border/shadow around its child for a few seconds —
/// used to draw attention to new emergency alerts.
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final bool active;
  final double borderRadius;
  final int cycles;

  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.active = true,
    this.borderRadius = 16,
    this.cycles = 8,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _c.reverse();
      } else if (s == AnimationStatus.dismissed && ++_done < widget.cycles && widget.active) {
        _c.forward();
      }
    });
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (!widget.active && _c.isAnimating) _c.animateTo(0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.35 * t),
                blurRadius: 6 + 14 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}

/// Lifts and slightly scales its child on hover / press.
class HoverLift extends StatefulWidget {
  final Widget child;
  const HoverLift({super.key, required this.child});

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    final scale = _down ? 0.98 : (_hover ? 1.02 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: Offset(0, _hover ? -0.02 : 0),
            duration: const Duration(milliseconds: 160),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Animates a text value change with a quick slide + fade (e.g. stock counts).
class AnimatedValueText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  const AnimatedValueText(this.text, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style, textAlign: textAlign),
    );
  }
}
