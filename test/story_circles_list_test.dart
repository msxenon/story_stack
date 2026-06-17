import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_circles_list.dart';
import 'package:story_stack/story_user_circle.dart';

import 'test_utils.dart';

void main() {
  List<StoryCircleUser> buildUsers() => [
    StoryCircleUser(
      id: 'u1',
      name: 'Alice',
      imageProvider: testAvatarImageProvider(),
      storyCount: 3,
    ),
    StoryCircleUser(
      id: 'u2',
      name: 'Bob',
      imageProvider: testAvatarImageProvider(),
      storyCount: 0,
    ),
    StoryCircleUser(
      id: 'u3',
      name: 'Carol',
      imageProvider: testAvatarImageProvider(),
      storyCount: 5,
      seenCount: 5,
    ),
  ];

  testWidgets('renders one StoryUserCircle per user', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryCirclesList(users: buildUsers(), shine: false),
      ),
    );
    await tester.pump();

    expect(find.byType(StoryUserCircle), findsNWidgets(3));
  });

  testWidgets('renders each user\'s name label', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryCirclesList(users: buildUsers(), shine: false),
      ),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
  });

  testWidgets('invokes onTapUser with the tapped index', (tester) async {
    final tappedIndexes = <int>[];
    await tester.pumpWidget(
      wrapWithApp(
        StoryCirclesList(
          users: buildUsers(),
          shine: false,
          onTapUser: tappedIndexes.add,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(StoryUserCircle).at(1));
    expect(tappedIndexes, [1]);

    await tester.tap(find.byType(StoryUserCircle).at(0));
    expect(tappedIndexes, [1, 0]);
  });

  testWidgets('renders an empty list without throwing', (tester) async {
    await tester.pumpWidget(wrapWithApp(const StoryCirclesList(users: [])));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(StoryUserCircle), findsNothing);
  });
}
