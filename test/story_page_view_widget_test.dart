import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_page_view.dart';

const _screenSize = Size(400, 800);

Widget _wrapFullScreen(Widget child) {
  return MaterialApp(debugShowCheckedModeBanner: false, home: child);
}

Future<void> _setScreenSize(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_screenSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Taps the right half of the screen (the "next story/page" gesture zone).
Future<void> _tapForward(WidgetTester tester) {
  return tester.tapAt(Offset(_screenSize.width * 0.75, _screenSize.height / 2));
}

/// Taps the left half of the screen (the "previous story/page" gesture
/// zone).
Future<void> _tapBackward(WidgetTester tester) {
  return tester.tapAt(Offset(_screenSize.width * 0.25, _screenSize.height / 2));
}

void main() {
  testWidgets('renders itemBuilder content for the initial page/story', (
    tester,
  ) async {
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) =>
              Text('p$pageIndex-s$storyIndex'),
          storyLength: (_) => 3,
          pageLength: 2,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('p0-s0'), findsOneWidget);
  });

  testWidgets('shows one progress indicator per story on the current page', (
    tester,
  ) async {
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) => const SizedBox(),
          storyLength: (_) => 4,
          pageLength: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('tapping the right half advances to the next story', (
    tester,
  ) async {
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) =>
              Text('p$pageIndex-s$storyIndex'),
          storyLength: (_) => 3,
          pageLength: 1,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('p0-s0'), findsOneWidget);

    await _tapForward(tester);
    await tester.pump();

    expect(find.text('p0-s1'), findsOneWidget);
  });

  testWidgets(
    'tapping the left half goes back to the previous story on the same page',
    (tester) async {
      await _setScreenSize(tester);
      await tester.pumpWidget(
        _wrapFullScreen(
          StoryPageView(
            itemBuilder: (context, pageIndex, storyIndex) =>
                Text('p$pageIndex-s$storyIndex'),
            storyLength: (_) => 3,
            pageLength: 1,
            initialStoryIndex: (_) => 1,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('p0-s1'), findsOneWidget);

      await _tapBackward(tester);
      await tester.pump();

      expect(find.text('p0-s0'), findsOneWidget);
    },
  );

  testWidgets(
    'calls onPageLimitReached when tapping forward past the last story of '
    'the last page',
    (tester) async {
      var reached = false;
      await _setScreenSize(tester);
      await tester.pumpWidget(
        _wrapFullScreen(
          StoryPageView(
            itemBuilder: (context, pageIndex, storyIndex) => const SizedBox(),
            storyLength: (_) => 1,
            pageLength: 1,
            onPageLimitReached: () => reached = true,
          ),
        ),
      );
      await tester.pump();
      expect(reached, isFalse);

      await _tapForward(tester);
      await tester.pump();

      expect(reached, isTrue);
    },
  );

  testWidgets('does not call onPageLimitReached before the last story', (
    tester,
  ) async {
    var reached = false;
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) => const SizedBox(),
          storyLength: (_) => 2,
          pageLength: 1,
          onPageLimitReached: () => reached = true,
        ),
      ),
    );
    await tester.pump();

    await _tapForward(tester);
    await tester.pump();

    expect(reached, isFalse);
  });

  testWidgets('initialPage and initialStoryIndex open at the right spot', (
    tester,
  ) async {
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) =>
              Text('p$pageIndex-s$storyIndex'),
          storyLength: (_) => 3,
          pageLength: 3,
          initialPage: 1,
          initialStoryIndex: (pageIndex) => pageIndex == 1 ? 2 : 0,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('p1-s2'), findsOneWidget);
  });

  testWidgets('pausing indicatorAnimationController stops the animation', (
    tester,
  ) async {
    final controller = ValueNotifier(IndicatorAnimationCommand.resume);
    addTearDown(controller.dispose);

    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) => const SizedBox(),
          storyLength: (_) => 1,
          pageLength: 1,
          indicatorDuration: const Duration(seconds: 5),
          indicatorAnimationController: controller,
        ),
      ),
    );
    await tester.pump();

    // Running by default: the indicator animates forward automatically.
    expect(tester.binding.hasScheduledFrame, isTrue);

    controller.value = IndicatorAnimationCommand.pause;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('resuming indicatorAnimationController restarts the animation', (
    tester,
  ) async {
    final controller = ValueNotifier(IndicatorAnimationCommand.pause);
    addTearDown(controller.dispose);

    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) => const SizedBox(),
          storyLength: (_) => 1,
          pageLength: 1,
          indicatorDuration: const Duration(seconds: 5),
          indicatorAnimationController: controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    controller.value = IndicatorAnimationCommand.resume;
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isTrue);

    // Stop it again so this test doesn't leave a live animation behind.
    controller.value = IndicatorAnimationCommand.pause;
    await tester.pumpAndSettle();
  });

  testWidgets('calls onPageChanged when swiping to another page', (
    tester,
  ) async {
    final changedTo = <int>[];
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) =>
              Text('p$pageIndex-s$storyIndex'),
          storyLength: (_) => 1,
          pageLength: 2,
          onPageChanged: changedTo.add,
        ),
      ),
    );
    await tester.pump();

    // Drag from a raw point rather than a Finder: the story content sits
    // underneath the full-screen tap-gesture layer, so hit-testing the
    // Text widget directly would (harmlessly) warn that it's obscured.
    await tester.dragFrom(
      Offset(_screenSize.width / 2, _screenSize.height / 2),
      Offset(-_screenSize.width, 0),
    );
    await tester.pumpAndSettle();

    expect(changedTo, contains(1));
    expect(find.text('p1-s0'), findsOneWidget);
  });

  testWidgets('renders gestureItemBuilder content above the story', (
    tester,
  ) async {
    await _setScreenSize(tester);
    await tester.pumpWidget(
      _wrapFullScreen(
        StoryPageView(
          itemBuilder: (context, pageIndex, storyIndex) => const SizedBox(),
          gestureItemBuilder: (context, pageIndex, storyIndex) =>
              const Text('close button'),
          storyLength: (_) => 1,
          pageLength: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('close button'), findsOneWidget);
  });
}
