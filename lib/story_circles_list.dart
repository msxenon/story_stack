import 'package:flutter/material.dart';
import 'package:story_stack/story_stack.dart';

/// Minimal data needed to render one entry in [StoryCirclesList].
class StoryCircleUser {
  const StoryCircleUser({
    required this.id,
    required this.name,
    required this.imageProvider,
    this.storyCount = 0,
    this.seenCount = 0,
  });

  /// Unique identifier for this user. Not used internally, but handy for
  /// callers to look the user back up from [StoryCirclesList.onTapUser].
  final String id;

  /// Name shown below the circle.
  final String name;

  /// Avatar image shown inside the ring.
  final ImageProvider imageProvider;

  /// Total number of stories this user has.
  final int storyCount;

  /// How many of [storyCount] have already been seen.
  final int seenCount;
}

/// Horizontally scrollable row of [StoryUserCircle]s, similar to the
/// "stories tray" at the top of Instagram's home feed.
class StoryCirclesList extends StatelessWidget {
  const StoryCirclesList({
    super.key,
    required this.users,
    this.onTapUser,
    this.circleSize = 64,
    this.maxVisibleSegments,
    this.spacing = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.nameStyle,
    this.backgroundColor = Colors.white,
    this.shine = true,
    this.seenColor = const Color(0xFFC7C7C7),
    this.gradientColors = const [
      Color(0xFFFEDA75),
      Color(0xFFFA7E1E),
      Color(0xFFD62976),
      Color(0xFF962FBF),
      Color(0xFF4F5BD5),
    ],
    this.delegate,
  });

  /// Users to render, in order.
  final List<StoryCircleUser> users;

  /// Called with the tapped user's index in [users].
  final void Function(int index)? onTapUser;

  /// Diameter of each [StoryUserCircle].
  final double circleSize;

  /// Forwarded to [StoryUserCircle.maxVisibleSegments].
  final int? maxVisibleSegments;

  /// Horizontal space between two circles.
  final double spacing;

  /// Padding around the scrollable row.
  final EdgeInsetsGeometry padding;

  /// Style of the name label below each circle.
  final TextStyle? nameStyle;

  /// Forwarded to [StoryUserCircle.backgroundColor].
  final Color backgroundColor;

  /// Forwarded to [StoryUserCircle.shine].
  final bool shine;

  /// Forwarded to [StoryUserCircle.seenColor].
  final Color seenColor;

  /// Forwarded to [StoryUserCircle.gradientColors].
  final List<Color> gradientColors;

  /// Forwarded to [StoryUserCircle.delegate]. Defaults to `null`, which
  /// falls back to the app-wide [StoryStack.delegate].
  final StoryStackDelegate? delegate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // circleSize for the ring/avatar, plus room below it for the 4px gap
      // and the name label (which can wrap font metrics slightly taller
      // than its nominal line height), plus the row's own vertical padding.
      height: circleSize + 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: users.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final user = users[index];
          return SizedBox(
            width: circleSize + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StoryUserCircle(
                  imageProvider: user.imageProvider,
                  storyCount: user.storyCount,
                  seenCount: user.seenCount,
                  size: circleSize,
                  maxVisibleSegments: maxVisibleSegments,
                  shine: shine,
                  seenColor: seenColor,
                  gradientColors: gradientColors,
                  backgroundColor: backgroundColor,
                  onTap: onTapUser == null ? null : () => onTapUser!(index),
                  delegate: delegate,
                ),
                const SizedBox(height: 4),
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: nameStyle ?? const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
