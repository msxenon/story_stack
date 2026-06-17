import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:story_stack/story_stack.dart';

/// Instagram-style avatar with a gradient "story ring" around it.
///
/// The ring is split into one arc per story, separated by small gaps, so a
/// user with 4 stories shows 4 distinct segments. Segments that have already
/// been seen are drawn in [seenColor]; unseen segments are drawn with a
/// rotating gradient to mimic Instagram's subtle "shine".
///
/// If [storyCount] is greater than [maxVisibleSegments], drawing one arc per
/// story would pack the segments (and the gaps between them) so tightly
/// they'd touch or overlap. In that case the ring is capped at
/// [maxVisibleSegments] evenly-spaced segments instead of one per story.
class StoryUserCircle extends StatefulWidget {
  const StoryUserCircle({
    super.key,
    required this.imageProvider,
    this.storyCount = 0,
    this.seenCount = 0,
    this.size = 64,
    this.strokeWidth = 2.5,
    this.ringGap = 3,
    this.gapAngle = 0.18,
    this.maxVisibleSegments,
    this.shine = true,
    this.seenColor = const Color(0xFFC7C7C7),
    this.gradientColors = const [
      Color(0xFFFEDA75),
      Color(0xFFFA7E1E),
      Color(0xFFD62976),
      Color(0xFF962FBF),
      Color(0xFF4F5BD5),
    ],
    this.backgroundColor,
    this.onTap,
    this.delegate,
    this.placeholderBuilder,
  });

  /// Image shown inside the ring.
  final ImageProvider imageProvider;

  /// Total number of stories this user has.
  ///
  /// `0` means the user has no stories, in which case no ring is drawn.
  final int storyCount;

  /// How many of [storyCount] stories have already been seen.
  ///
  /// The first [seenCount] segments (in clockwise order) are drawn as seen.
  final int seenCount;

  /// Outer diameter of the whole widget (ring + avatar).
  final double size;

  /// Thickness of the ring stroke.
  final double strokeWidth;

  /// Gap between the ring and the avatar image.
  final double ringGap;

  /// Angle (in radians) reserved as empty space between two adjacent
  /// segments. Ignored when there's only a single segment.
  final double gapAngle;

  /// Maximum number of individual story segments to render.
  ///
  /// When [storyCount] exceeds this, the ring is capped at this many
  /// evenly-spaced segments instead of drawing one arc per story.
  ///
  /// Defaults to `null`, which auto-calculates the max from [size],
  /// [strokeWidth] and [gapAngle] so segments never get packed so tightly
  /// they touch or overlap. Pass an explicit value to override that.
  final int? maxVisibleSegments;

  /// Whether unseen segments should slowly rotate their gradient to create a
  /// subtle shine/shimmer effect.
  final bool shine;

  /// Color used for segments that have already been seen.
  final Color seenColor;

  /// Gradient colors used for segments that have not been seen yet.
  final List<Color> gradientColors;

  /// Color of the thin gap between the ring and the avatar.
  final Color? backgroundColor;

  /// Called when the circle is tapped.
  final VoidCallback? onTap;

  /// Strategy hooks for internal calculations, e.g. how many segments fit
  /// around the ring. Implement [StoryStackDelegate] (or extend
  /// [DefaultStoryStackDelegate]) and pass an instance to change that
  /// behavior for just this widget, without forking it.
  ///
  /// Defaults to `null`, which falls back to the app-wide
  /// [StoryStack.delegate].
  final StoryStackDelegate? delegate;

  /// Builds the widget shown in place of the avatar while [imageProvider]
  /// is still loading its first frame (e.g. a network image that hasn't
  /// downloaded yet).
  ///
  /// Defaults to `null`, which uses a plain grey circle with a small
  /// spinner ([_defaultPlaceholder]). Pass your own builder — a shimmer
  /// effect, a branded placeholder, a blurhash, etc. — to replace it. The
  /// builder is given the avatar's diameter so the placeholder can size
  /// itself to match.
  final Widget Function(BuildContext context, double diameter)?
  placeholderBuilder;

  @override
  State<StoryUserCircle> createState() => _StoryUserCircleState();
}

class _StoryUserCircleState extends State<StoryUserCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  /// [StoryUserCircle.storyCount], guarded against a caller accidentally
  /// passing a negative value (which would otherwise crash
  /// `List<bool>.generate` below).
  int get _storyCount => max(0, widget.storyCount);

  /// [StoryUserCircle.seenCount], clamped to a sane `[0, _storyCount]`
  /// range so an out-of-range value (negative, or larger than
  /// [StoryUserCircle.storyCount]) can't push the "seen" ratio outside
  /// 0%-100%.
  int get _seenCount => widget.seenCount.clamp(0, _storyCount);

  bool get _hasStories => _storyCount > 0;

  bool get _hasUnseenStories => _seenCount < _storyCount;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _syncShineAnimation();
  }

  @override
  void didUpdateWidget(covariant StoryUserCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncShineAnimation();
  }

  void _syncShineAnimation() {
    final shouldShine = widget.shine && _hasStories && _hasUnseenStories;
    if (shouldShine) {
      if (!_shineController.isAnimating) {
        _shineController.repeat();
      }
    } else {
      _shineController.stop();
    }
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = (widget.size - widget.strokeWidth) / 2;
    final delegate = widget.delegate ?? StoryStack.delegate;
    final effectiveMaxSegments =
        widget.maxVisibleSegments ??
        delegate.calculateMaxStorySegments(
          radius: radius,
          strokeWidth: widget.strokeWidth,
          gapAngle: widget.gapAngle,
          storyCount: _storyCount,
        );
    final segments = !_hasStories
        ? 0
        : (_storyCount > effectiveMaxSegments
              ? effectiveMaxSegments
              : _storyCount);

    // One flag per *drawn* segment, not per story: when segments is capped
    // below _storyCount, mapping seenCount directly onto the first N
    // stories would make a handful of capped segments look fully "seen"
    // regardless of the real seen ratio (e.g. storyCount: 100, seenCount:
    // 50, segments: 10 would previously mark all 10 segments as seen,
    // since the first 10 stories happen to be seen). Instead, each segment
    // i represents the stories up to `(i+1) * storyCount / segments`, and
    // counts as seen only once every story it represents has been seen —
    // this also still works for the segments == 1 fallback, where it
    // naturally reduces to "every story has been seen".
    final seenFlags = List<bool>.generate(segments, (i) {
      final storiesUpToThisSegment = ((i + 1) * _storyCount / segments).ceil();
      return _seenCount >= storiesUpToThisSegment;
    });

    final ringInnerDiameter = max(0.0, widget.size - widget.strokeWidth * 2);
    final avatarDiameter = max(0.0, ringInnerDiameter - widget.ringGap * 2);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (segments > 0)
              AnimatedBuilder(
                animation: _shineController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _StoryRingPainter(
                      segments: segments,
                      seenFlags: seenFlags,
                      strokeWidth: widget.strokeWidth,
                      gapAngle: segments > 1 ? widget.gapAngle : 0,
                      seenColor: widget.seenColor,
                      gradientColors: widget.gradientColors,
                      shineRotation: _shineController.value * 2 * pi,
                    ),
                  );
                },
              ),
            Container(
              width: ringInnerDiameter,
              height: ringInnerDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.backgroundColor ?? Colors.transparent,
              ),
            ),
            ClipOval(
              child: Image(
                image: widget.imageProvider,
                width: avatarDiameter,
                height: avatarDiameter,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  // wasSynchronouslyLoaded: provider resolved instantly
                  // (e.g. MemoryImage, an already-cached image) — nothing
                  // to show a placeholder for.
                  // frame != null: at least one frame has been decoded.
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return widget.placeholderBuilder?.call(
                        context,
                        avatarDiameter,
                      ) ??
                      _defaultPlaceholder(avatarDiameter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Default placeholder shown while the avatar image loads: a plain grey
  /// circle with a small centered spinner, sized to fill [diameter].
  Widget _defaultPlaceholder(double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      color: Colors.blue,
      alignment: Alignment.center,
      child: SizedBox(
        width: diameter * 0.3,
        height: diameter * 0.3,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _StoryRingPainter extends CustomPainter {
  _StoryRingPainter({
    required this.segments,
    required this.seenFlags,
    required this.strokeWidth,
    required this.gapAngle,
    required this.seenColor,
    required this.gradientColors,
    required this.shineRotation,
  });

  /// Number of arcs to draw. `1` means a single, unsplit ring.
  final int segments;

  /// Seen state per drawn segment — always `segments` long. When
  /// [segments] is `1` (the collapsed fallback ring), this is a single
  /// flag for whether every story has been seen.
  final List<bool> seenFlags;

  final double strokeWidth;
  final double gapAngle;
  final Color seenColor;
  final List<Color> gradientColors;

  /// Rotation (radians) applied to the unseen gradient to create the shine
  /// effect. Segment boundaries are not affected by this.
  final double shineRotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // SweepGradient jumps straight from its last color back to the first
    // one at the 0/2π seam. Repeating the first color at the end makes that
    // seam fade smoothly instead of showing a hard edge while it rotates.
    final gradientShader = SweepGradient(
      colors: [...gradientColors, gradientColors.first],
      transform: GradientRotation(shineRotation),
    ).createShader(arcRect);

    final seenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = seenColor;

    final unseenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradientShader;

    if (segments <= 1) {
      final allSeen = seenFlags.isNotEmpty && seenFlags.every((s) => s);
      // Leave a hair of a gap so the round caps don't visibly overlap.
      canvas.drawArc(
        arcRect,
        -pi / 2,
        2 * pi - 0.001,
        false,
        allSeen ? seenPaint : unseenPaint,
      );
      return;
    }

    final totalGap = gapAngle * segments;
    final sweepPerSegment = (2 * pi - totalGap) / segments;
    var startAngle = -pi / 2;
    for (var i = 0; i < segments; i++) {
      final isSeen = i < seenFlags.length && seenFlags[i];
      canvas.drawArc(
        arcRect,
        startAngle,
        sweepPerSegment,
        false,
        isSeen ? seenPaint : unseenPaint,
      );
      startAngle += sweepPerSegment + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _StoryRingPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapAngle != gapAngle ||
        oldDelegate.seenColor != seenColor ||
        oldDelegate.shineRotation != shineRotation ||
        // seenFlags/gradientColors are rebuilt as new list instances on
        // every build (List.generate, literal), so a reference (!=)
        // comparison here would always be true and make shouldRepaint
        // pointless — compare contents instead.
        !listEquals(oldDelegate.seenFlags, seenFlags) ||
        !listEquals(oldDelegate.gradientColors, gradientColors);
  }
}
