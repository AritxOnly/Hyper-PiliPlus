import 'dart:async' show unawaited;
import 'dart:math' show pi, sin;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

const double _cardRadius = 12;
const double _pageRadius = 72;
final ImageFilter _backgroundBlurFilter = ImageFilter.blur(
  sigmaX: 8,
  sigmaY: 8,
);

/// A video card that grows into the complete playback page.
class VideoCardHero extends StatelessWidget {
  const VideoCardHero({
    super.key,
    required this.tag,
    required this.child,
  });

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      flightShuttleBuilder: _buildFlightShuttle,
      child: ClipRRect(
        borderRadius: const .all(.circular(_cardRadius)),
        child: child,
      ),
    );
  }
}

/// Places the matching Hero just outside the viewport, so its growing corners
/// finish beyond the screen while the rounded surface still covers every pixel.
class VideoPageHeroTarget extends StatefulWidget {
  const VideoPageHeroTarget({
    super.key,
    required this.tag,
    required this.surfaceColor,
    required this.child,
  });

  final Object tag;
  final Color surfaceColor;
  final Widget child;

  @override
  State<VideoPageHeroTarget> createState() => _VideoPageHeroTargetState();
}

class _VideoPageHeroTargetState extends State<VideoPageHeroTarget> {
  Animation<double>? _routeAnimation;
  bool _samplingPaused = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    _routeAnimation = animation;
    animation?.addStatusListener(_handleAnimationStatus);
    if (animation != null) {
      _handleAnimationStatus(animation.status);
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    final shouldPause =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (_samplingPaused == shouldPause) return;
    _samplingPaused = shouldPause;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        PiliAndroidHelper.setMiuixBackdropSamplingPaused(shouldPause),
      );
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    if (_samplingPaused &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      unawaited(PiliAndroidHelper.setMiuixBackdropSamplingPaused(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeAnimation = _routeAnimation;
    final pageOpacity = routeAnimation == null
        ? null
        : CurvedAnimation(
            parent: routeAnimation,
            curve: const Interval(0.22, 1, curve: Curves.easeOutCubic),
          );
    final backdropOpacity = routeAnimation == null
        ? null
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: Curves.easeOutCubic),
              ),
              weight: 42,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.0).chain(
                CurveTween(curve: Curves.easeInCubic),
              ),
              weight: 58,
            ),
          ]).animate(routeAnimation);
    return Stack(
      fit: .expand,
      clipBehavior: .none,
      children: [
        if (backdropOpacity != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                key: const ValueKey('video-transition-backdrop'),
                opacity: backdropOpacity,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: _backgroundBlurFilter,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.035),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (routeAnimation == null)
          widget.child
        else
          FadeTransition(
            key: const ValueKey('video-transition-page'),
            opacity: pageOpacity!,
            child: widget.child,
          ),
        Positioned(
          left: -_pageRadius,
          top: -_pageRadius,
          right: -_pageRadius,
          bottom: -_pageRadius,
          child: IgnorePointer(
            child: Hero(
              tag: widget.tag,
              transitionOnUserGestures: true,
              createRectTween: (begin, end) =>
                  RectTween(begin: begin, end: end),
              flightShuttleBuilder: _buildFlightShuttle,
              child: _VideoPageSurface(color: widget.surfaceColor),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoPageSurface extends StatelessWidget {
  const _VideoPageSurface({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _buildFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final cardContext = direction == HeroFlightDirection.push
      ? fromHeroContext
      : toHeroContext;
  final pageContext = direction == HeroFlightDirection.push
      ? toHeroContext
      : fromHeroContext;
  final cardHero = cardContext.widget as Hero;
  final pageHero = pageContext.widget as Hero;
  final pageSurface = pageHero.child as _VideoPageSurface;
  final renderBox = cardContext.findRenderObject() as RenderBox?;
  final cardSize = renderBox?.size ?? const Size(1, 1);
  final card = InheritedTheme.captureAll(
    cardContext,
    Material(type: .transparency, child: cardHero.child),
  );

  return AnimatedBuilder(
    animation: animation,
    child: card,
    builder: (context, child) {
      final progress = Curves.easeInOutCubic.transform(animation.value);
      final radius = lerpDouble(_cardRadius, _pageRadius, progress)!;
      final surfaceOpacity = 0.84 * sin(pi * progress);
      final cardOpacity =
          1 -
          const Interval(
            0.10,
            0.82,
            curve: Curves.easeInOutCubic,
          ).transform(progress);

      return ClipRRect(
        borderRadius: .all(.circular(radius)),
        child: Stack(
          fit: .expand,
          children: [
            ColoredBox(
              color: pageSurface.color.withValues(alpha: surfaceOpacity),
            ),
            if (cardOpacity > 0)
              Opacity(
                opacity: cardOpacity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox.fromSize(size: cardSize, child: child),
                ),
              ),
          ],
        ),
      );
    },
  );
}
