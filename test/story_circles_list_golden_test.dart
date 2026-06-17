import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_circles_list.dart';

import 'test_utils.dart';

List<StoryCircleUser> _buildUsers({required bool withNames}) {
  Widget? nameFor(String name) => withNames ? Text(name) : null;

  return [
    StoryCircleUser(
      id: 'u1',
      name: nameFor('Alice'),
      imageProvider: testAvatarImageProvider(),
      storyCount: 4,
    ),
    StoryCircleUser(
      id: 'u2',
      name: nameFor('Bob'),
      imageProvider: testAvatarImageProvider(),
      storyCount: 4,
      seenCount: 2,
    ),
    StoryCircleUser(
      id: 'u3',
      name: nameFor('Carol'),
      imageProvider: testAvatarImageProvider(),
      storyCount: 3,
      seenCount: 3,
    ),
    StoryCircleUser(
      id: 'u4',
      name: nameFor('Dave'),
      imageProvider: testAvatarImageProvider(),
    ),
  ];
}

Future<void> _pumpGolden(
  WidgetTester tester,
  List<StoryCircleUser> users, {
  required String name,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 120));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.black,
        child: StoryCirclesList(users: users, shine: false),
      ),
    ),
  );
  await tester.pump();

  await expectLater(
    find.byType(StoryCirclesList),
    matchesGoldenFile('story_circles_list_golden_test/$name.png'),
  );
}

void main() {
  testWidgets(
    'renders a row of named circles with mixed seen/unseen/no-story states',
    (tester) async {
      await _pumpGolden(
        tester,
        _buildUsers(withNames: true),
        name: 'named_row',
      );
    },
  );

  testWidgets(
    'renders the same row without name labels (no extra height reserved)',
    (tester) async {
      await _pumpGolden(
        tester,
        _buildUsers(withNames: false),
        name: 'unnamed_row',
      );
    },
  );
}
