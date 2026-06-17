import 'package:flutter/material.dart';
import 'package:story_stack/story_stack.dart';

/// Minimal data needed to render one entry in [StoryCirclesList].
class StoryCircleUser {
  const StoryCircleUser({
    required this.id,
    this.name,
    required this.imageProvider,
    this.storyCount = 0,
    this.seenCount = 0,
  });

  /// Unique identifier for this user. Not used internally, but handy for
  /// callers to look the user back up from [StoryCirclesList.onTapUser].
  final String id;

  /// Widget shown below the circle, e.g. a `Text(userName)`.
  ///
  /// Optional — when left `null`, no label (and no extra space for one)
  /// is rendered, leaving just the circle. Since this takes an arbitrary
  /// widget rather than a plain string, it isn't limited to text: pass
  /// any widget you like (an icon, a row, etc).
  final Widget? name;

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
    this.backgroundColor,
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
    this.placeholderBuilder,
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

  /// Forwarded to [StoryUserCircle.backgroundColor].
  final Color? backgroundColor;

  /// Forwarded to [StoryUserCircle.shine].
  final bool shine;

  /// Forwarded to [StoryUserCircle.seenColor].
  final Color seenColor;

  /// Forwarded to [StoryUserCircle.gradientColors].
  final List<Color> gradientColors;

  /// Forwarded to [StoryUserCircle.delegate]. Defaults to `null`, which
  /// falls back to the app-wide [StoryStack.delegate].
  final StoryStackDelegate? delegate;

  /// Forwarded to [StoryUserCircle.placeholderBuilder].
  final Widget Function(BuildContext context, double diameter)?
  placeholderBuilder;

  /// Whether any user has a [StoryCircleUser.name] widget, used to decide
  /// whether the row needs extra height reserved below the circles.
  bool get _hasAnyName => users.any((user) => user.name != null);

  /// Extra vertical room reserved below the circle for the 4px gap plus
  /// the name label itself, when at least one user has one.
  static const double _labelReserve = 32;

  @override
  Widget build(BuildContext context) {
    // circleSize for the ring/avatar, plus the row's *actual* vertical
    // padding (previously hardcoded assuming the default `padding`, which
    // would overflow again if a caller passed a taller one), plus — only
    // if at least one user has a name widget — room for the label.
    final resolvedPadding = padding.resolve(Directionality.of(context));
    final height =
        circleSize +
        resolvedPadding.vertical +
        (_hasAnyName ? _labelReserve : 0);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: users.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
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
                  placeholderBuilder: placeholderBuilder,
                ),
                if (user.name != null) ...[
                  const SizedBox(height: 4),
                  user.name!,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
