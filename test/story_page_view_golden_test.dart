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
}
