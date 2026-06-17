import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_page_view.dart';

void main() {
  testWidgets(
    'renders a page with content, 3 indicator segments and a shadow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(300, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Pause the indicator from the very first frame so the captured
      // golden is deterministic regardless of animation timing.
      final controller = ValueNotifier(IndicatorAnimationCommand.pause);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StoryPageView(
            itemBuilder: (context, pageIndex, storyIndex) {
              return Container(
                color: Colors.blueGrey,
                alignment: Alignment.center,
                child: Text(
                  'Story $storyIndex',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              );
            },
            storyLength: (_) => 3,
            pageLength: 1,
            indicatorAnimationController: controller,
            showShadow: true,
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(StoryPageView),
        matchesGoldenFile('story_page_view_golden_test/initial_frame.png'),
      );
    },
  );

  testWidgets('mid pull-to-dismiss: scaled, faded and rounded', (tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = ValueNotifier(IndicatorAnimationCommand.pause);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) {
            return Container(color: Colors.blueGrey);
          },
          storyLength: (_) => 3,
          pageLength: 1,
          indicatorAnimationController: controller,
        ),
      ),
    );
    await tester.pump();

    // Halfway through the dismiss drag, finger still down (using
    // startGesture rather than dragFrom so the gesture doesn't release
    // and trigger the snap-back/dismiss before the golden is captured).
    //
    // Moved in several small increments rather than one big jump: a
    // single moveBy only crosses the recognizer's slop threshold and
    // fires onDragStart, with no further movement left to report via
    // onDragUpdate — so the drag would never actually appear to move.
    final gesture = await tester.startGesture(const Offset(150, 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 12.5));
      await tester.pump();
    }

    await expectLater(
      find.byType(StoryPageView),
      matchesGoldenFile('story_page_view_golden_test/mid_pull_to_dismiss.png'),
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
