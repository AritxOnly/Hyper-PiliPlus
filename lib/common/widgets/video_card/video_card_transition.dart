import 'dart:async' show unawaited;
import 'dart:ui' as ui show Image, ImageFilter, TileMode, lerpDouble;

import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:get/get.dart' show GetPageRoute;
import 'package:material_ui/material_ui.dart';

const double _cardRadius = 12;
const double _pageRadius = 72;
const double _expansionEnd = 0.72;
const double _surfaceFadeInStart = 0.66;
const double _surfaceFadeInEnd = 0.80;
const double _heroSurfaceFadeOutStart = 0.72;
const double _heroSurfaceFadeOutEnd = 0.84;
const Duration videoPageTransitionDuration = Duration(milliseconds: 560);
const Duration videoPageReverseTransitionDuration = Duration(milliseconds: 500);
final ui.ImageFilter _backgroundBlurFilter = ui.ImageFilter.blur(
  sigmaX: 6,
  sigmaY: 6,
  tileMode: ui.TileMode.clamp,
);
final GlobalKey videoTransitionCaptureBoundaryKey = GlobalKey(
  debugLabel: 'video-transition-capture-boundary',
);
_CapturedVideoTransition? _pendingVideoTransition;

class _CapturedVideoTransition {
  const _CapturedVideoTransition({required this.tag, required this.image});

  final Object tag;
  final ui.Image? image;
}

bool hasPendingVideoCardTransition(Object tag) =>
    _pendingVideoTransition?.tag == tag;

_CapturedVideoTransition? _claimVideoCardTransition(Object tag) {
  if (!hasPendingVideoCardTransition(tag)) return null;
  final transition = _pendingVideoTransition;
  _pendingVideoTransition = null;
  return transition;
}

void _captureVideoTransitionBackground(Object tag) {
  ui.Image? image;
  final boundary = videoTransitionCaptureBoundaryKey.currentContext
      ?.findRenderObject();
  if (boundary is RenderRepaintBoundary && boundary.hasSize) {
    try {
      image = boundary.toImageSync(pixelRatio: 1);
    } catch (_) {
      // The live blur fallback remains available when a platform cannot capture.
    }
  }
  _pendingVideoTransition?.image?.dispose();
  _pendingVideoTransition = _CapturedVideoTransition(tag: tag, image: image);
}

double _expansionProgress(double value) => Curves.easeInOutCubic.transform(
  (value / _expansionEnd).clamp(0.0, 1.0),
);

// Express the previous return flight in card-to-page coordinates. Both flights
// now evaluate this same function; Hero itself must not apply another curve.
double _containerProgress(double value) =>
    1 - _expansionProgress(1 - Curves.fastOutSlowIn.flipped.transform(value));

class _VideoCardRectTween extends RectTween {
  _VideoCardRectTween({
    required super.begin,
    required super.end,
    this.returning = false,
  });

  final bool returning;

  @override
  Rect? lerp(double t) => Rect.lerp(
    begin,
    end,
    returning ? 1 - _containerProgress(1 - t) : _containerProgress(t),
  );
}

/// A longer, otherwise transparent route used by the two-stage video Hero.
class VideoPageTransitionRoute<T> extends GetPageRoute<T> {
  VideoPageTransitionRoute({
    required WidgetBuilder builder,
    super.settings,
  }) : super(
         page: () => Builder(builder: builder),
       );

  // Playback screens and controller cleanup rely on GetPageRoute's lifecycle.
  // Only replace its visual transition, not the route implementation.
  @override
  Duration get transitionDuration => videoPageTransitionDuration;

  @override
  Duration get reverseTransitionDuration => videoPageReverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
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
    return Listener(
      onPointerDown: (_) => _captureVideoTransitionBackground(tag),
      child: Hero(
        tag: tag,
        curve: Curves.linear,
        reverseCurve: Curves.linear,
        transitionOnUserGestures: true,
        createRectTween: (begin, end) =>
            _VideoCardRectTween(begin: begin, end: end, returning: true),
        flightShuttleBuilder: _buildFlightShuttle,
        child: ClipRRect(
          borderRadius: const .all(.circular(_cardRadius)),
          child: child,
        ),
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
  late final SnapshotController _backdropSnapshotController;
  late final _CapturedVideoTransition? _capturedTransition;
  late final bool _hasSharedTransition;
  bool _samplingPaused = false;

  @override
  void initState() {
    super.initState();
    _capturedTransition = _claimVideoCardTransition(widget.tag);
    _hasSharedTransition = _capturedTransition != null;
    _backdropSnapshotController = SnapshotController()
      ..allowSnapshotting = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSharedTransition) return;
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
    _backdropSnapshotController.dispose();
    _capturedTransition?.image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSharedTransition) return widget.child;
    final routeAnimation = _routeAnimation;
    final backdropOpacity = routeAnimation == null
        ? null
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: ConstantTween(0),
              weight: 32,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.0, end: 1.0).chain(
                CurveTween(curve: Curves.easeOutCubic),
              ),
              weight: 18,
            ),
            TweenSequenceItem(
              tween: ConstantTween(1),
              weight: 8,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.0).chain(
                CurveTween(curve: Curves.easeInOutCubic),
              ),
              weight: 18,
            ),
            TweenSequenceItem(
              tween: ConstantTween(0),
              weight: 24,
            ),
          ]).animate(routeAnimation);
    final pageSurfaceOpacity = routeAnimation == null
        ? null
        : CurveTween(
            curve: const Interval(
              _surfaceFadeInStart,
              _surfaceFadeInEnd,
              curve: Curves.easeInOutCubic,
            ),
          ).animate(routeAnimation);
    final pageOpacity = routeAnimation == null
        ? kAlwaysCompleteAnimation
        : CurveTween(
            curve: const Interval(0.68, 1, curve: Curves.easeInCubic),
          ).animate(routeAnimation);
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
                child: SnapshotWidget(
                  controller: _backdropSnapshotController,
                  mode: SnapshotMode.permissive,
                  child: _TransitionBackdrop(
                    snapshot: _capturedTransition?.image,
                  ),
                ),
              ),
            ),
          ),
        if (routeAnimation != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                key: const ValueKey('video-transition-page-surface-opacity'),
                opacity: pageSurfaceOpacity!,
                child: ColoredBox(
                  key: const ValueKey('video-transition-page-surface'),
                  color: widget.surfaceColor,
                ),
              ),
            ),
          ),
        if (routeAnimation == null)
          widget.child
        else
          FadeTransition(
            key: const ValueKey('video-transition-page'),
            opacity: pageOpacity,
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
              curve: Curves.linear,
              reverseCurve: Curves.linear,
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

class _TransitionBackdrop extends StatelessWidget {
  const _TransitionBackdrop({required this.snapshot});

  final ui.Image? snapshot;

  @override
  Widget build(BuildContext context) {
    final image = snapshot;
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image == null)
            BackdropFilter(
              filter: _backgroundBlurFilter,
              child: const SizedBox.expand(),
            )
          else
            ImageFiltered(
              imageFilter: _backgroundBlurFilter,
              child: RawImage(
                image: image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
            ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.055)),
        ],
      ),
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
      final progress = _containerProgress(animation.value);
      final radius = ui.lerpDouble(_cardRadius, _pageRadius, progress)!;
      final cardOpacity =
          1 -
          const Interval(
            0.08,
            0.88,
            curve: Curves.easeInOutCubic,
          ).transform(progress);
      final surfaceOpacity =
          1 -
          const Interval(
            _heroSurfaceFadeOutStart,
            _heroSurfaceFadeOutEnd,
            curve: Curves.easeInOutCubic,
          ).transform(animation.value);
      final surfaceColor = Color.lerp(
        cardSurface,
        pageSurface.color,
        progress,
      )!.withValues(alpha: surfaceOpacity);

      return ClipRRect(
        key: const ValueKey('video-transition-flight'),
        borderRadius: .all(.circular(radius)),
        child: Stack(
          fit: .expand,
          children: [
            ColoredBox(
              color: surfaceColor,
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
