import 'dart:math';

/// Pluggable strategy hooks used by [StoryUserCircle] and
/// [StoryCirclesList].
///
/// The widgets ship with [DefaultStoryStackDelegate], but some of their
/// internal math — like how many story segments fit around a ring before
/// they'd start touching — is exposed here so it can be swapped out
/// without forking the widgets. Implement this interface (or extend
/// [DefaultStoryStackDelegate] to reuse its defaults and override just one
/// method) and pass your instance via `delegate:`.
///
/// ```dart
/// class FixedSegmentsDelegate extends DefaultStoryStackDelegate {
///   const FixedSegmentsDelegate(this.fixedSegments);
///
///   final int fixedSegments;
///
///   @override
///   int calculateMaxStorySegments({
///     required double radius,
///     required double strokeWidth,
///     required double gapAngle,
///     required int storyCount,
///   }) {
///     return fixedSegments;
///   }
/// }
/// ```
abstract class StoryStackDelegate {
  const StoryStackDelegate();

  /// Largest number of segments that can be drawn around a ring of
  /// [radius] without the dashes (or their gaps) shrinking below a size
  /// that's still visually distinguishable.
  ///
  /// [storyCount] is provided as a hint for implementations that want to
  /// use it as a search upper bound (a ring can never need more segments
  /// than it has stories), but it doesn't have to be honored that way.
  int calculateMaxStorySegments({
    required double radius,
    required double strokeWidth,
    required double gapAngle,
    required int storyCount,
  });
}

/// Default [StoryStackDelegate] implementation used by [StoryUserCircle]
/// and [StoryCirclesList] when no custom `delegate:` is supplied.
class DefaultStoryStackDelegate extends StoryStackDelegate {
  const DefaultStoryStackDelegate();

  /// Largest number of segments that can be drawn around a ring of
  /// [radius] without the dashes (or their gaps) shrinking below a size
  /// that's still visually distinguishable.
  ///
  /// Tries increasing segment counts one by one, using the same
  /// sweep-angle formula the ring painter uses, and stops as soon as a
  /// candidate count would make a dash shorter than [strokeWidth] — the
  /// last count that still passed is the answer.
  ///
  /// [storyCount] is used purely as a search upper bound: a ring can never
  /// need more segments than it has stories, so searching past it is
  /// wasted work.
  @override
  int calculateMaxStorySegments({
    required double radius,
    required double strokeWidth,
    required double gapAngle,
    required int storyCount,
  }) {
    if (radius <= 0) return 1;

    var bestFit = 1;
    final searchLimit = max(1, storyCount);
    for (var candidate = 1; candidate <= searchLimit; candidate++) {
      final totalGap = gapAngle * candidate;
      final sweepPerSegment = (2 * pi - totalGap) / candidate;
      if (sweepPerSegment <= 0) break;

      // A dash roughly as long as the stroke is thick still reads as a
      // distinct segment instead of a sliver.
      final sweepArcLength = sweepPerSegment * radius;
      if (sweepArcLength < strokeWidth) break;

      bestFit = candidate;
    }
    return bestFit;
  }
}
