import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

const double _cardRadius = 12;
const double _pageRadius = 72;
const double _expansionEnd = 0.68;
const Duration _pageRevealDuration = Duration(milliseconds: 180);
const Duration _pageHideDuration = Duration(milliseconds: 90);
final ImageFilter _backgroundBlurFilter = ImageFilter.blur(
  sigmaX: 8,
  sigmaY: 8,
);

double _expansionProgress(double value) => Curves.easeInOutCubic.transform(
  (value / _expansionEnd).clamp(0.0, 1.0),
);

class _VideoCardRectTween extends RectTween {
  _VideoCardRectTween({required super.begin, required super.end});

  @override
  Rect? lerp(double t) => Rect.lerp(begin, end, _expansionProgress(t));
}

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
      createRectTween: (begin, end) =>
          _VideoCardRectTween(begin: begin, end: end),
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

class _VideoPageHeroTargetState extends State<VideoPageHeroTarget>
    with SingleTickerProviderStateMixin {
  Animation<double>? _routeAnimation;
  late final AnimationController _pageRevealController;
  late final Animation<double> _pageOpacity;
  bool _samplingPaused = false;

  @override
  void initState() {
    super.initState();
    _pageRevealController = AnimationController(
      vsync: this,
      duration: _pageRevealDuration,
      reverseDuration: _pageHideDuration,
    );
    _pageOpacity = CurvedAnimation(
      parent: _pageRevealController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeListener(_handleRouteAnimationValue);
    _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    _routeAnimation = animation;
    animation?.addListener(_handleRouteAnimationValue);
    animation?.addStatusListener(_handleAnimationStatus);
    if (animation != null) {
      _handleAnimationStatus(animation.status);
      _handleRouteAnimationValue();
    } else {
      _pageRevealController.value = 1;
    }
  }

  void _handleRouteAnimationValue() {
    final animation = _routeAnimation;
    if (animation?.status == AnimationStatus.forward &&
        animation!.value >= _expansionEnd &&
        _pageRevealController.status == AnimationStatus.dismissed) {
      _pageRevealController.forward();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        if (_routeAnimation?.value case final value?
            when value < _expansionEnd) {
          _pageRevealController.value = 0;
        }
      case AnimationStatus.completed:
        _pageRevealController.forward();
      case AnimationStatus.reverse:
        _pageRevealController.reverse();
      case AnimationStatus.dismissed:
        _pageRevealController.value = 0;
    }
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
    _routeAnimation?.removeListener(_handleRouteAnimationValue);
    _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    if (_samplingPaused &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      unawaited(PiliAndroidHelper.setMiuixBackdropSamplingPaused(false));
    }
    _pageRevealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeAnimation = _routeAnimation;
    final backdropOpacity = routeAnimation == null
        ? null
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: Curves.easeOutCubic),
              ),
              weight: _expansionEnd * 100,
            ),
            TweenSequenceItem(
              tween: ConstantTween(0),
              weight: (1 - _expansionEnd) * 100,
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
        if (routeAnimation != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: routeAnimation,
                builder: (context, child) => ColoredBox(
                  key: const ValueKey('video-transition-page-surface'),
                  color: routeAnimation.value >= _expansionEnd
                      ? widget.surfaceColor
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        if (routeAnimation == null)
          widget.child
        else
          FadeTransition(
            key: const ValueKey('video-transition-page'),
            opacity: _pageOpacity,
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
                  _VideoCardRectTween(begin: begin, end: end),
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
  final cardSurface = Theme.of(cardContext).colorScheme.surfaceContainer;
  final card = InheritedTheme.captureAll(
    cardContext,
    Material(type: .transparency, child: cardHero.child),
  );

  return AnimatedBuilder(
    animation: animation,
    child: card,
    builder: (context, child) {
      final progress = _expansionProgress(animation.value);
      final radius = lerpDouble(_cardRadius, _pageRadius, progress)!;
      final cardOpacity =
          1 -
          const Interval(
            0.08,
            0.88,
            curve: Curves.easeInOutCubic,
          ).transform(progress);
      final isPagePhase = animation.value >= _expansionEnd;

      return ClipRRect(
        borderRadius: .all(.circular(radius)),
        child: Stack(
          fit: .expand,
          children: [
            ColoredBox(
              color: isPagePhase
                  ? Colors.transparent
                  : Color.lerp(cardSurface, pageSurface.color, progress)!,
            ),
            if (cardOpacity > 0)
              Align(
                alignment: Alignment.topLeft,
                child: Opacity(
                  opacity: cardOpacity,
                  child: SizedBox.fromSize(
                    size: cardSize,
                    child: RepaintBoundary(child: child),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
