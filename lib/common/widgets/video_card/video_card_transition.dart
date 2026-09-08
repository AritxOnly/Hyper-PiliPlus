import 'dart:math' show pi, sin;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:material_ui/material_ui.dart';

const double _cardRadius = 12;
const double _pageRadius = 72;

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
class VideoPageHeroTarget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    return Stack(
      fit: .expand,
      clipBehavior: .none,
      children: [
        if (routeAnimation == null)
          child
        else
          FadeTransition(
            opacity: CurvedAnimation(
              parent: routeAnimation,
              curve: const Interval(0.18, 1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        if (routeAnimation != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: routeAnimation,
                builder: (context, child) {
                  final pulse = sin(pi * routeAnimation.value);
                  if (pulse <= 0.001) {
                    return const SizedBox.shrink();
                  }
                  return ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 16 * pulse,
                        sigmaY: 16 * pulse,
                      ),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.05 * pulse),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        Positioned(
          left: -_pageRadius,
          top: -_pageRadius,
          right: -_pageRadius,
          bottom: -_pageRadius,
          child: IgnorePointer(
            child: Hero(
              tag: tag,
              transitionOnUserGestures: true,
              createRectTween: (begin, end) =>
                  RectTween(begin: begin, end: end),
              flightShuttleBuilder: _buildFlightShuttle,
              child: _VideoPageSurface(color: surfaceColor),
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
      final blurPulse = sin(pi * progress);
      final cardOpacity =
          1 -
          const Interval(
            0.28,
            0.82,
            curve: Curves.easeOutCubic,
          ).transform(progress);

      return ClipRRect(
        borderRadius: .all(.circular(radius)),
        child: Stack(
          fit: .expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 16 * blurPulse,
                sigmaY: 16 * blurPulse,
              ),
              child: ColoredBox(
                color: Color.lerp(
                  Colors.transparent,
                  pageSurface.color,
                  progress,
                )!,
              ),
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
