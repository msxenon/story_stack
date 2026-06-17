import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_stack.dart';

import 'test_utils.dart';

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

void main() {
  testWidgets('renders the avatar image', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 3,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('draws no ring when storyCount is 0', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(StoryUserCircle(imageProvider: testAvatarImageProvider())),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('draws a ring when storyCount is greater than 0', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 4,
          shine: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('invokes onTap when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 2,
          shine: false,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(StoryUserCircle));
    expect(tapped, isTrue);
  });

  testWidgets('does not schedule animation frames when shine is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 4,
          shine: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('does not schedule animation frames when every story is seen', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 4,
          seenCount: 4,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'schedules animation frames when shine is true and a story is unseen',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          StoryUserCircle(
            imageProvider: testAvatarImageProvider(),
            storyCount: 4,
            seenCount: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.binding.hasScheduledFrame, isTrue);

      // Stop the animation so the pump loop in tearDown doesn't run forever.
      await tester.pumpWidget(
        wrapWithApp(
          StoryUserCircle(
            imageProvider: testAvatarImageProvider(),
            storyCount: 4,
            seenCount: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('collapses storyCount past maxVisibleSegments to a single '
      'ring without throwing', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 53,
          maxVisibleSegments: 8,
          shine: false,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('uses a custom delegate to decide the max segment count when '
      'maxVisibleSegments is left unset', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 53,
          shine: false,
          delegate: const _FixedSegmentsDelegate(7),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('falls back to StoryStack.delegate when delegate is left unset', (
    tester,
  ) async {
    final originalDelegate = StoryStack.delegate;
    addTearDown(() => StoryStack.delegate = originalDelegate);

    var calls = 0;
    StoryStack.delegate = _CountingDelegate(
      onCalculate: () => calls++,
      fixedSegments: 5,
    );

    await tester.pumpWidget(
      wrapWithApp(
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 53,
          shine: false,
        ),
      ),
    );
    await tester.pump();

    expect(calls, greaterThan(0));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets(
    'an explicit delegate takes precedence over StoryStack.delegate',
    (tester) async {
      final originalDelegate = StoryStack.delegate;
      addTearDown(() => StoryStack.delegate = originalDelegate);

      var globalCalls = 0;
      StoryStack.delegate = _CountingDelegate(
        onCalculate: () => globalCalls++,
        fixedSegments: 5,
      );

      await tester.pumpWidget(
        wrapWithApp(
          StoryUserCircle(
            imageProvider: testAvatarImageProvider(),
            storyCount: 53,
            shine: false,
            delegate: const _FixedSegmentsDelegate(7),
          ),
        ),
      );
      await tester.pump();

      expect(globalCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CountingDelegate extends StoryStackDelegate {
  _CountingDelegate({required this.onCalculate, required this.fixedSegments});

  final void Function() onCalculate;
  final int fixedSegments;

  @override
  int calculateMaxStorySegments({
    required double radius,
    required double strokeWidth,
    required double gapAngle,
    required int storyCount,
  }) {
    onCalculate();
    return fixedSegments;
  }
}
