import 'dart:async' show unawaited;
import 'dart:ui' as ui show lerpDouble;

import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:get/get.dart' show GetPageRoute;
import 'package:material_ui/material_ui.dart';

const double _cardRadius = 12;
const double _pageRadius = 72;
const Curve _containerCurve = Interval(0, 0.66, curve: Curves.easeOutCubic);
const Curve _revealCurve = Interval(0.42, 0.66, curve: Curves.easeInOutCubic);
const Duration videoPageTransitionDuration = Duration(milliseconds: 560);
const Duration videoPageReverseTransitionDuration = Duration(milliseconds: 500);
({Object tag, RenderBox box, BuildContext context})? _pendingVideoTransition;

/// For transparent cards, use the actual painted ancestor rather than a
/// hard-coded surface role. Opaque cards pass their own Material color.
Color transitionBackgroundOf(BuildContext context) {
  Color? result;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    final Color? color = switch (widget) {
      Material(:final type, :final color)
          when type != MaterialType.transparency =>
        color ?? Theme.of(element).canvasColor,
      ColoredBox(:final color) => color,
      DecoratedBox(decoration: BoxDecoration(:final color)) => color,
      _ => null,
    };
    if (color != null && color.a == 1) {
      result = color;
      return false;
    }
    return true;
  });
  return result ?? Theme.of(context).scaffoldBackgroundColor;
}

Color _transitionSurface(Color card, Color page, double expansion) =>
    Color.lerp(card, page, expansion)!;

bool hasPendingVideoCardTransition(Object tag) =>
    _pendingVideoTransition?.tag == tag;

// Keep only geometry: tapping no longer captures or filters a full-screen image.
void _prepareVideoTransition(Object tag, BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    _pendingVideoTransition = (
      tag: tag,
      box: box,
      context: context,
    );
  }
}

class _VideoCardRectTween extends RectTween {
  _VideoCardRectTween({required super.begin, required super.end});

  @override
  Rect? lerp(double t) => Rect.lerp(begin, end, _containerCurve.transform(t));
}

/// Retain GetX's playback/controller lifecycle, replacing only the visuals.
class VideoPageTransitionRoute<T> extends GetPageRoute<T> {
  VideoPageTransitionRoute({required WidgetBuilder builder, super.settings})
    : super(page: () => Builder(builder: builder));

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

class VideoCardHero extends StatelessWidget {
  const VideoCardHero({
    super.key,
    required this.tag,
    required this.surfaceColor,
    required this.child,
    this.preserveChildHeroes = false,
  });

  final Object tag;
  final Color surfaceColor;
  final Widget child;
  final bool preserveChildHeroes;

  @override
  Widget build(BuildContext context) {
    final hero = Hero(
      tag: tag,
      curve: Curves.linear,
      reverseCurve: Curves.linear,
      transitionOnUserGestures: true,
      createRectTween: (begin, end) =>
          _VideoCardRectTween(begin: begin, end: end),
      flightShuttleBuilder: _buildFlightShuttle,
      child: _CardSurface(
        color: surfaceColor,
        flightChild: preserveChildHeroes ? child : null,
        child: preserveChildHeroes ? const SizedBox.expand() : child,
      ),
    );
    return Listener(
      onPointerDown: (_) => _prepareVideoTransition(tag, context),
      // Dynamic cards contain independent image-preview Heroes. Keep the card
      // flight anchor as their sibling, never an enclosing Hero.
      child: preserveChildHeroes
          ? Stack(
              children: [
                child,
                Positioned.fill(child: IgnorePointer(child: hero)),
              ],
            )
          : hero,
    );
  }
}

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
  RenderBox? _sourceBox;
  Rect? _sourceRect;
  Color? _sourceColor;
  BuildContext? _sourceContext;
  bool _samplingPaused = false;

  @override
  void initState() {
    super.initState();
    if (hasPendingVideoCardTransition(widget.tag)) {
      _sourceBox = _pendingVideoTransition!.box;
      _sourceContext = _pendingVideoTransition!.context;
      _sourceColor = (_sourceContext!.widget as VideoCardHero).surfaceColor;
      _sourceRect = _sourceBox!.localToGlobal(Offset.zero) & _sourceBox!.size;
      _pendingVideoTransition = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sourceRect == null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    _routeAnimation = animation;
    animation?.addStatusListener(_handleAnimationStatus);
    if (animation != null) _handleAnimationStatus(animation.status);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && _sourceContext?.mounted == true) {
      _sourceColor = (_sourceContext!.widget as VideoCardHero).surfaceColor;
    }
    final box = _sourceBox;
    if (status == AnimationStatus.reverse &&
        box != null &&
        box.attached &&
        box.hasSize) {
      _sourceRect = box.localToGlobal(Offset.zero) & box.size;
    }
    final shouldPause =
        status == AnimationStatus.forward || status == AnimationStatus.reverse;
    if (_samplingPaused == shouldPause) return;
    _samplingPaused = shouldPause;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(PiliAndroidHelper.setMiuixBackdropSamplingPaused(shouldPause));
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
    final animation = _routeAnimation;
    if (_sourceRect == null || animation == null) return widget.child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final viewport = Offset.zero & size;
        final reveal = CurveTween(curve: _revealCurve).animate(animation);
        return AnimatedBuilder(
          animation: animation,
          child: widget.child,
          builder: (context, child) {
            final returning = animation.status == AnimationStatus.reverse;
            final box = context.findRenderObject();
            final origin = box is RenderBox && box.hasSize
                ? box.localToGlobal(Offset.zero)
                : Offset.zero;
            final source = _sourceRect!.shift(-origin);
            final expansion = _containerCurve.transform(animation.value);
            final contraction = Curves.easeInOutCubic.transform(
              1 - animation.value,
            );
            // Fade with the actual shrink, never before movement starts.
            // A stronger ease-out makes return content disappear earlier.
            final returnOpacity =
                1 - Curves.easeOutCubic.transform(contraction);
            final surfaceColor = _transitionSurface(
              _sourceColor!,
              widget.surfaceColor,
              returning ? 1 - contraction : expansion,
            );
            final pageRect = returning
                ? Rect.lerp(viewport, source, contraction)!
                : viewport;
            final clipRect = returning
                ? Offset.zero & pageRect.size
                : Rect.lerp(source, viewport.inflate(_pageRadius), expansion)!;
            final radius = returning
                ? _cardRadius * contraction
                : ui.lerpDouble(_cardRadius, _pageRadius, expansion)!;
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                if (!returning && animation.status != AnimationStatus.completed)
                  Positioned.fill(
                    key: const ValueKey('video-transition-dim-position'),
                    child: IgnorePointer(
                      child: ColoredBox(
                        key: const ValueKey('video-transition-dim'),
                        color: Colors.black.withValues(alpha: 0.16 * expansion),
                      ),
                    ),
                  ),
                Positioned.fromRect(
                  key: const ValueKey('video-transition-page-position'),
                  rect: pageRect,
                  child: ClipRRect(
                    key: const ValueKey('video-transition-page-container'),
                    clipper: _PageClipper(clipRect, radius),
                    child: ColoredBox(
                      key: const ValueKey('video-transition-surface'),
                      // Keep the interpolated surface underneath fading content
                      // and match the Hero color throughout the entry handoff.
                      color: surfaceColor,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox.fromSize(
                          size: size,
                          child: FadeTransition(
                            key: const ValueKey('video-transition-page'),
                            opacity: returning
                                ? AlwaysStoppedAnimation(returnOpacity)
                                : reveal,
                            child: RepaintBoundary(child: child),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('video-transition-hero-position'),
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
          },
        );
      },
    );
  }
}

class _PageClipper extends CustomClipper<RRect> {
  const _PageClipper(this.rect, this.radius);
  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_PageClipper oldClipper) =>
      rect != oldClipper.rect || radius != oldClipper.radius;
}

class _VideoPageSurface extends StatelessWidget {
  const _VideoPageSurface({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({
    required this.color,
    required this.child,
    this.flightChild,
  });
  final Color color;
  final Widget child;
  final Widget? flightChild;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(Radius.circular(_cardRadius)),
    child: child,
  );
}

Widget _buildFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  // Shrink the mounted page on return; never duplicate its playback state.
  if (direction == HeroFlightDirection.pop) return const SizedBox.expand();
  final cardHero = fromHeroContext.widget as Hero;
  final pageSurface = (toHeroContext.widget as Hero).child as _VideoPageSurface;
  final renderBox = fromHeroContext.findRenderObject() as RenderBox?;
  final cardSize = renderBox?.size ?? const Size(1, 1);
  final cardSurface = (cardHero.child as _CardSurface).color;
  final card = InheritedTheme.captureAll(
    fromHeroContext,
    Material(
      type: MaterialType.transparency,
      child: (cardHero.child as _CardSurface).flightChild ?? cardHero.child,
    ),
  );
  return AnimatedBuilder(
    animation: animation,
    child: card,
    builder: (context, child) {
      final progress = _containerCurve.transform(animation.value);
      final radius = ui.lerpDouble(_cardRadius, _pageRadius, progress)!;
      final cardOpacity =
          1 -
          const Interval(
            0.08,
            0.88,
            curve: Curves.easeInOutCubic,
          ).transform(progress);
      return ClipRRect(
        key: const ValueKey('video-transition-flight'),
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        child: Opacity(
          opacity: 1 - _revealCurve.transform(animation.value),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                key: const ValueKey('video-transition-flight-surface'),
                color: _transitionSurface(
                  cardSurface,
                  pageSurface.color,
                  progress,
                ),
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
        ),
      );
    },
  );
}
