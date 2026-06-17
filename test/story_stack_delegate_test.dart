import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_stack_delegate.dart';

void main() {
  group('DefaultStoryStackDelegate.calculateMaxStorySegments', () {
    const delegate = DefaultStoryStackDelegate();

    test('returns 1 when radius is zero or negative', () {
      expect(
        delegate.calculateMaxStorySegments(
          radius: 0,
          strokeWidth: 2.5,
          gapAngle: 0.18,
          storyCount: 10,
        ),
        1,
      );
      expect(
        delegate.calculateMaxStorySegments(
          radius: -10,
          strokeWidth: 2.5,
          gapAngle: 0.18,
          storyCount: 10,
        ),
        1,
      );
    });

    test('never returns more segments than storyCount', () {
      // A huge radius with a tiny stroke could fit hundreds of segments,
      // but there's no point splitting the ring into more arcs than there
      // are stories to represent.
      final result = delegate.calculateMaxStorySegments(
        radius: 1000,
        strokeWidth: 0.1,
        gapAngle: 0.01,
        storyCount: 3,
      );
      expect(result, lessThanOrEqualTo(3));
    });

    test('collapses to 1 when a second segment would not fit, even though '
        'a single full-circle dash still does', () {
      // At radius=5, gapAngle=0.18: a 1-segment dash is ~30.5px long, but a
      // 2-segment dash is only ~14.8px long. A strokeWidth between those
      // forces the search to stop right after the first candidate.
      final result = delegate.calculateMaxStorySegments(
        radius: 5,
        strokeWidth: 20,
        gapAngle: 0.18,
        storyCount: 20,
      );
      expect(result, 1);
    });

    test('every returned segment count keeps dashes at least strokeWidth '
        'long', () {
      const radius = 30.0;
      const strokeWidth = 2.5;
      const gapAngle = 0.18;

      for (final storyCount in [1, 2, 4, 8, 20, 53, 100]) {
        final segments = delegate.calculateMaxStorySegments(
          radius: radius,
          strokeWidth: strokeWidth,
          gapAngle: gapAngle,
          storyCount: storyCount,
        );

        final totalGap = gapAngle * segments;
        final sweepPerSegment = (2 * pi - totalGap) / segments;
        final dashLength = sweepPerSegment * radius;

        expect(
          dashLength,
          greaterThanOrEqualTo(strokeWidth),
          reason:
              'storyCount=$storyCount produced $segments segments whose '
              'dash length ($dashLength) is shorter than strokeWidth '
              '($strokeWidth)',
        );
      }
    });

    test('one more segment than the result would violate the minimum dash '
        'length (the result is the *tightest* fit, not an arbitrary safe '
        'one)', () {
      const radius = 30.0;
      const strokeWidth = 2.5;
      const gapAngle = 0.18;
      const storyCount = 100;

      final segments = delegate.calculateMaxStorySegments(
        radius: radius,
        strokeWidth: strokeWidth,
        gapAngle: gapAngle,
        storyCount: storyCount,
      );

      // The search stops at storyCount even if more would technically fit,
      // so only assert tightness when there's room to grow within
      // storyCount.
      if (segments < storyCount) {
        final nextCandidate = segments + 1;
        final totalGap = gapAngle * nextCandidate;
        final sweepPerSegment = (2 * pi - totalGap) / nextCandidate;
        final dashLength = sweepPerSegment * radius;
        expect(dashLength, lessThan(strokeWidth));
      }
    });

    test('larger radius allows more segments, all else equal', () {
      final small = delegate.calculateMaxStorySegments(
        radius: 10,
        strokeWidth: 2.5,
        gapAngle: 0.18,
        storyCount: 1000,
      );
      final large = delegate.calculateMaxStorySegments(
        radius: 100,
        strokeWidth: 2.5,
        gapAngle: 0.18,
        storyCount: 1000,
      );
      expect(large, greaterThan(small));
    });

    test('regression: storyCount=53 on a 64px circle collapses to far '
        'fewer segments than 53 (no near-touching slivers)', () {
      // size=64, strokeWidth=2.5 -> radius = (64 - 2.5) / 2
      const radius = (64 - 2.5) / 2;
      final segments = delegate.calculateMaxStorySegments(
        radius: radius,
        strokeWidth: 2.5,
        gapAngle: 0.18,
        storyCount: 53,
      );
      expect(segments, lessThan(53));
    });
  });

  group('StoryStackDelegate is overridable', () {
    test('a subclass can replace the fit heuristic entirely', () {
      // Demonstrates the documented extension point: callers can subclass
      // StoryStackDelegate to plug in their own logic, e.g. a fixed cap
      // regardless of geometry.
      const delegate = _FixedSegmentsDelegate(7);

      final result = delegate.calculateMaxStorySegments(
        radius: 1,
        strokeWidth: 100,
        gapAngle: 0.18,
        storyCount: 1000,
      );

      expect(result, 7);
    });
  });
}

class _FixedSegmentsDelegate extends StoryStackDelegate {
  const _FixedSegmentsDelegate(this.fixedSegments);

  final int fixedSegments;

  @override
  int calculateMaxStorySegments({
    required double radius,
    required double strokeWidth,
    required double gapAngle,
    required int storyCount,
  }) {
    return fixedSegments;
  }
}
