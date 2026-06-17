import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_user_circle.dart';

import 'test_utils.dart';

void main() {
  // Animation is disabled (shine: false) in every case so the captured
  // frame is deterministic regardless of timing.
  const goldenSize = Size(96, 96);

  Future<void> pumpGolden(
    WidgetTester tester,
    Widget widget, {
    required String name,
  }) async {
    await tester.binding.setSurfaceSize(goldenSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: Colors.black,
          child: Center(child: widget),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(StoryUserCircle),
      matchesGoldenFile('story_user_circle_golden_test/$name.png'),
    );
  }

  testWidgets('no stories: bare avatar, no ring', (tester) async {
    await pumpGolden(
      tester,
      StoryUserCircle(
        imageProvider: testAvatarImageProvider(),
        storyCount: 0,
      ),
      name: 'story_user_circle_no_stories',
    );
  });

  testWidgets('single story, unseen: full gradient ring', (tester) async {
    await pumpGolden(
      tester,
      StoryUserCircle(
        imageProvider: testAvatarImageProvider(),
        storyCount: 1,
        shine: false,
      ),
      name: 'story_user_circle_single_unseen',
    );
  });

  testWidgets('single story, seen: full grey ring', (tester) async {
    await pumpGolden(
      tester,
      StoryUserCircle(
        imageProvider: testAvatarImageProvider(),
        storyCount: 1,
        seenCount: 1,
      ),
      name: 'story_user_circle_single_seen',
    );
  });

  testWidgets('multiple stories, all unseen: segmented gradient ring', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      StoryUserCircle(
        imageProvider: testAvatarImageProvider(),
        storyCount: 4,
        shine: false,
      ),
      name: 'story_user_circle_segments_unseen',
    );
  });

  testWidgets('multiple stories, partially seen: mixed segments', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      StoryUserCircle(
        imageProvider: testAvatarImageProvider(),
        storyCount: 4,
        seenCount: 2,
        shine: false,
      ),
      name: 'story_user_circle_segments_partially_seen',
    );
  });

  testWidgets('multiple stories, all seen: grey segmented ring', (
    tester,
  ) async {
    await pumpGolden(
      tester,
      StoryUserCircle(
        imageProvider: testAvatarImageProvider(),
        storyCount: 4,
        seenCount: 4,
      ),
      name: 'story_user_circle_segments_all_seen',
    );
  });

  testWidgets(
    'storyCount far past auto max: caps to the largest segment count that '
    'still fits without the dashes touching',
    (tester) async {
      await pumpGolden(
        tester,
        StoryUserCircle(
          imageProvider: testAvatarImageProvider(),
          storyCount: 53,
          shine: false,
        ),
        name: 'story_user_circle_collapsed_ring',
      );
    },
  );
}
