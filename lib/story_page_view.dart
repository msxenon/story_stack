import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:story_stack/story_image.dart';

typedef StoryItemBuilder =
    Widget Function(BuildContext context, int pageIndex, int storyIndex);

typedef StoryConfigFunction = int Function(int pageIndex);

enum IndicatorAnimationCommand { pause, resume }

/// PageView to implement story like UI
///
/// [itemBuilder], [storyLength], [pageLength] are required.
class StoryPageView extends StatefulWidget {
  const StoryPageView({
    super.key,
    required this.itemBuilder,
    required this.storyLength,
    required this.pageLength,
    this.gestureItemBuilder,
    this.initialStoryIndex,
    this.initialPage = 0,
    this.onPageLimitReached,
    this.indicatorDuration = const Duration(seconds: 5),
    this.indicatorPadding = const EdgeInsets.symmetric(
      vertical: 32,
      horizontal: 8,
    ),
    this.backgroundColor = Colors.black,
    this.indicatorAnimationController,
    this.onPageChanged,
    this.indicatorVisitedColor = Colors.white,
    this.indicatorUnvisitedColor = Colors.grey,
    this.indicatorHeight = 2,
    this.indicatorRadius = 10,
    this.showShadow = false,
    this.enablePullToDismiss = true,
    this.onDismiss,
  });

  ///  visited color of [_Indicators]
  final Color indicatorVisitedColor;

  ///  unvisited color of [_Indicators]
  final Color indicatorUnvisitedColor;

  /// Function to build story content
  final StoryItemBuilder itemBuilder;

  /// Function to build story content
  /// Components with gesture actions are expected
  /// Placed above the story gestures.
  final StoryItemBuilder? gestureItemBuilder;

  /// decides length of story for each page
  final StoryConfigFunction storyLength;

  /// length of [StoryPageView]
  final int pageLength;

  /// Initial index of story for each page
  final StoryConfigFunction? initialStoryIndex;

  /// padding of [_Indicators]
  final EdgeInsetsGeometry indicatorPadding;

  /// duration of [_Indicators]
  final Duration indicatorDuration;

  /// Called when the very last story is finished.
  ///
  /// Functions like "Navigator.pop(context)" is expected.
  final VoidCallback? onPageLimitReached;

  /// Called whenever the page in the center of the viewport changes.
  final void Function(int)? onPageChanged;

  /// initial index for [StoryPageView]
  final int initialPage;

  /// Color under the Stories which is visible when the cube transition is in progress
  final Color backgroundColor;

  /// Width of indicator
  final double indicatorHeight;

  /// radius of indicator
  final double indicatorRadius;

  /// Whether to show shadow near indicator
  final bool showShadow;

  /// A stream with [IndicatorAnimationCommand] to force pause or continue inticator animation
  /// Useful when you need to show any popup over the story
  final ValueNotifier<IndicatorAnimationCommand>? indicatorAnimationController;

  /// Whether dragging down (like Instagram) shrinks/fades the story and,
  /// if released past the halfway point of the screen, pops it.
  ///
  /// Dragging down less than halfway, or releasing above the halfway
  /// point, snaps the story back to its normal position instead.
  final bool enablePullToDismiss;

  /// Called right before [StoryPageView] pops itself in response to a
  /// completed pull-to-dismiss drag (see [enablePullToDismiss]).
  ///
  /// Optional — the pop happens regardless of whether this is provided;
  /// use it for side effects (e.g. analytics, persisting "seen" state),
  /// not to control whether the pop happens.
  final VoidCallback? onDismiss;

  @override
  State<StoryPageView> createState() => _StoryPageViewState();
}

class _StoryPageViewState extends State<StoryPageView>
    with SingleTickerProviderStateMixin {
  late PageController pageController;

  late double currentPageValue;

  /// Vertical pixels currently dragged down by the pull-to-dismiss
  /// gesture. `0` when not dragging (or snapped back).
  double _dragExtent = 0;

  /// Global Y of the most recent drag update, used at release time to
  /// decide whether the finger ended up in the bottom half of the screen.
  double _lastDragGlobalY = 0;

  bool _isDismissDragging = false;

  /// Drives the "snap back to normal position" animation when a drag is
  /// released without crossing the dismiss threshold. Not used for the
  /// drag itself, which tracks the finger directly.
  late final AnimationController _snapBackController;
  Animation<double>? _snapBackAnimation;
  VoidCallback? _snapBackListener;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.initialPage);

    currentPageValue = widget.initialPage.toDouble();

    pageController.addListener(() {
      setState(() {
        // PageController.page is null until the PageView has attached and
        // laid out at least once; fall back to the last known value
        // instead of letting a transient null reach the arithmetic below.
        currentPageValue = pageController.page ?? currentPageValue;
      });
    });

    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  void _handlePullToDismissStart(DragStartDetails details) {
    if (!widget.enablePullToDismiss) return;
    _isDismissDragging = true;
    _clearSnapBackAnimation();
    _snapBackController.stop();
  }

  void _handlePullToDismissUpdate(DragUpdateDetails details) {
    if (!widget.enablePullToDismiss || !_isDismissDragging) return;
    setState(() {
      // Only follow downward drags; ignore upward movement instead of
      // letting the story get dragged off the top of the screen.
      _dragExtent = max(0.0, _dragExtent + details.delta.dy);
      _lastDragGlobalY = details.globalPosition.dy;
    });
  }

  void _handlePullToDismissEnd(DragEndDetails details) {
    if (!widget.enablePullToDismiss || !_isDismissDragging) return;
    _isDismissDragging = false;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final releasedInBottomHalf = _lastDragGlobalY > screenHeight / 2;

    if (_dragExtent > 0 && releasedInBottomHalf) {
      widget.onDismiss?.call();
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        // Nothing to pop (e.g. StoryPageView isn't inside a route of its
        // own) — snap back instead of leaving the story stuck mid-drag.
        _animateDragBack();
      }
    } else {
      _animateDragBack();
    }
  }

  void _animateDragBack() {
    _clearSnapBackAnimation();
    final animation = Tween<double>(begin: _dragExtent, end: 0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOut),
    );
    void listener() => setState(() => _dragExtent = animation.value);
    animation.addListener(listener);
    _snapBackAnimation = animation;
    _snapBackListener = listener;
    _snapBackController.forward(from: 0).whenCompleteOrCancel(() {
      _clearSnapBackAnimation();
    });
  }

  void _clearSnapBackAnimation() {
    if (_snapBackAnimation != null && _snapBackListener != null) {
      _snapBackAnimation!.removeListener(_snapBackListener!);
    }
    _snapBackAnimation = null;
    _snapBackListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Fully "committed" (scaled/faded as far as it'll go) once dragged
    // down by half the screen height — the same distance that decides
    // whether releasing now would dismiss.
    final dismissProgress = screenHeight > 0
        ? (_dragExtent / (screenHeight / 2)).clamp(0.0, 1.0)
        : 0.0;
    final scale = lerpDouble(1, 0.85, dismissProgress)!;
    // Instagram-style: the card grows rounded corners as it's pulled down,
    // instead of staying square the whole time.
    final cornerRadius = lerpDouble(0, 24, dismissProgress)!;

    return GestureDetector(
      onVerticalDragStart: _handlePullToDismissStart,
      onVerticalDragUpdate: _handlePullToDismissUpdate,
      onVerticalDragEnd: _handlePullToDismissEnd,
      child: Transform.translate(
        offset: Offset(0, _dragExtent),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: lerpDouble(1, 0.3, dismissProgress)!,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cornerRadius),
              child: _buildPageView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageView(BuildContext context) {
    return ColoredBox(
      color: widget.backgroundColor,
      child: PageView.builder(
        controller: pageController,
        itemCount: widget.pageLength,
        onPageChanged: widget.onPageChanged,
        itemBuilder: (context, index) {
          final isLeaving = (index - currentPageValue) <= 0;
          final t = (index - currentPageValue);
          final rotationY = lerpDouble(0, 30, t)!;
          const maxOpacity = 0.8;
          final double opacity = lerpDouble(
            0,
            maxOpacity,
            t.abs(),
          )!.clamp(0.0, maxOpacity);
          final isPaging = opacity != maxOpacity;
          final transform = Matrix4.identity();
          transform.setEntry(3, 2, 0.003);
          transform.rotateY(-rotationY * (pi / 180.0));
          return Transform(
            alignment: isLeaving ? Alignment.centerRight : Alignment.centerLeft,
            transform: transform,
            child: Stack(
              children: [
                _StoryPageBuilder.wrapped(
                  showShadow: widget.showShadow,
                  backgroundColor: widget.backgroundColor,
                  indicatorHeight: widget.indicatorHeight,
                  indicatorRadius: widget.indicatorRadius,
                  pageLength: widget.pageLength,
                  storyLength: widget.storyLength(index),
                  initialStoryIndex: widget.initialStoryIndex?.call(index) ?? 0,
                  pageIndex: index,
                  animateToPage: (index) {
                    pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.ease,
                    );
                  },
                  isCurrentPage: currentPageValue == index,
                  isPaging: isPaging,
                  onPageLimitReached: widget.onPageLimitReached,
                  itemBuilder: widget.itemBuilder,
                  gestureItemBuilder: widget.gestureItemBuilder,
                  indicatorDuration: widget.indicatorDuration,
                  indicatorPadding: widget.indicatorPadding,
                  indicatorAnimationController:
                      widget.indicatorAnimationController,
                  indicatorUnvisitedColor: widget.indicatorUnvisitedColor,
                  indicatorVisitedColor: widget.indicatorVisitedColor,
                ),
                if (isPaging && !isLeaving)
                  Positioned.fill(
                    child: Opacity(
                      opacity: opacity,
                      child: const ColoredBox(color: Colors.black87),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryPageBuilder extends StatefulWidget {
  const _StoryPageBuilder._({
    required this.storyLength,
    required this.initialStoryIndex,
    required this.pageIndex,
    required this.isCurrentPage,
    required this.isPaging,
    required this.itemBuilder,
    required this.gestureItemBuilder,
    required this.indicatorDuration,
    required this.indicatorPadding,
    required this.indicatorAnimationController,
    required this.indicatorUnvisitedColor,
    required this.indicatorVisitedColor,
    required this.indicatorHeight,
    required this.indicatorRadius,
    required this.showShadow,
    required this.backgroundColor,
  });
  final int storyLength;
  final int initialStoryIndex;
  final int pageIndex;
  final bool isCurrentPage;
  final bool isPaging;
  final StoryItemBuilder itemBuilder;
  final StoryItemBuilder? gestureItemBuilder;
  final Duration indicatorDuration;
  final EdgeInsetsGeometry indicatorPadding;
  final ValueNotifier<IndicatorAnimationCommand>? indicatorAnimationController;
  final Color indicatorVisitedColor;
  final Color indicatorUnvisitedColor;
  final double indicatorHeight;
  final double indicatorRadius;
  final bool showShadow;
  final Color backgroundColor;

  static Widget wrapped({
    required int pageIndex,
    required int pageLength,
    required ValueChanged<int> animateToPage,
    required int storyLength,
    required int initialStoryIndex,
    required bool isCurrentPage,
    required bool isPaging,
    required VoidCallback? onPageLimitReached,
    required StoryItemBuilder itemBuilder,
    StoryItemBuilder? gestureItemBuilder,
    required Duration indicatorDuration,
    required EdgeInsetsGeometry indicatorPadding,
    required ValueNotifier<IndicatorAnimationCommand>?
    indicatorAnimationController,
    required Color indicatorVisitedColor,
    required Color indicatorUnvisitedColor,
    required double indicatorHeight,
    required double indicatorRadius,
    required bool showShadow,
    required Color backgroundColor,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => _StoryLimitController()),
        ChangeNotifierProvider(
          create: (context) => _StoryStackController(
            storyLength: storyLength,
            onPageBack: () {
              if (pageIndex != 0) {
                animateToPage(pageIndex - 1);
              }
            },
            onPageForward: () {
              if (pageIndex == pageLength - 1) {
                context.read<_StoryLimitController>().onPageLimitReached(
                  onPageLimitReached,
                );
              } else {
                animateToPage(pageIndex + 1);
              }
            },
            initialStoryIndex: initialStoryIndex,
          ),
        ),
      ],
      child: _StoryPageBuilder._(
        showShadow: showShadow,
        storyLength: storyLength,
        initialStoryIndex: initialStoryIndex,
        pageIndex: pageIndex,
        isCurrentPage: isCurrentPage,
        isPaging: isPaging,
        itemBuilder: itemBuilder,
        gestureItemBuilder: gestureItemBuilder,
        indicatorDuration: indicatorDuration,
        indicatorPadding: indicatorPadding,
        indicatorAnimationController: indicatorAnimationController,
        indicatorVisitedColor: indicatorVisitedColor,
        indicatorUnvisitedColor: indicatorUnvisitedColor,
        indicatorHeight: indicatorHeight,
        indicatorRadius: indicatorRadius,
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  State<_StoryPageBuilder> createState() => _StoryPageBuilderState();
}

class _StoryPageBuilderState extends State<_StoryPageBuilder>
    with
        AutomaticKeepAliveClientMixin<_StoryPageBuilder>,
        SingleTickerProviderStateMixin {
  late AnimationController animationController;

  late VoidCallback indicatorListener;
  late VoidCallback imageLoadingListener;

  @override
  void initState() {
    super.initState();

    indicatorListener = () {
      if (widget.isCurrentPage) {
        switch (widget.indicatorAnimationController?.value) {
          case IndicatorAnimationCommand.pause:
            animationController.stop();
            break;
          case IndicatorAnimationCommand.resume:
          default:
            if (storyImageLoadingController.value ==
                StoryImageLoadingState.loading) {
              return;
            }
            animationController.forward();
            break;
        }
      }
    };
    imageLoadingListener = () {
      if (widget.isCurrentPage) {
        switch (storyImageLoadingController.value) {
          case StoryImageLoadingState.loading:
            animationController.stop();
            break;
          case StoryImageLoadingState.available:
            if (widget.indicatorAnimationController?.value ==
                IndicatorAnimationCommand.pause) {
              return;
            }
            animationController.forward();
            break;
        }
      }
    };
    animationController =
        AnimationController(vsync: this, duration: widget.indicatorDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              context.read<_StoryStackController>().increment(
                restartAnimation: () => animationController.forward(from: 0),
              );
            }
          });
    widget.indicatorAnimationController?.addListener(indicatorListener);
    storyImageLoadingController.addListener(imageLoadingListener);
  }

  @override
  void dispose() {
    widget.indicatorAnimationController?.removeListener(indicatorListener);
    storyImageLoadingController.removeListener(imageLoadingListener);
    // animationController is created here, so it should be disposed here
    // too, rather than relying on the child _Indicators widget (which
    // doesn't own it) to do it.
    animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.topLeft,
      children: [
        Positioned.fill(child: ColoredBox(color: widget.backgroundColor)),
        Positioned.fill(
          child: widget.itemBuilder(
            context,
            widget.pageIndex,
            context.watch<_StoryStackController>().value,
          ),
        ),
        Container(
          height: 50,
          decoration: widget.showShadow
              ? BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      spreadRadius: 10,
                      blurRadius: 20,
                    ),
                  ],
                )
              : null,
        ),
        _Indicators(
          indicatorHeight: widget.indicatorHeight,
          indicatorRadius: widget.indicatorRadius,
          storyLength: widget.storyLength,
          animationController: animationController,
          isCurrentPage: widget.isCurrentPage,
          isPaging: widget.isPaging,
          padding: widget.indicatorPadding,
          indicatorVisitedColor: widget.indicatorVisitedColor,
          indicatorUnvisitedColor: widget.indicatorUnvisitedColor,
          indicatorAnimationController: widget.indicatorAnimationController,
        ),
        _Gestures(animationController: animationController),
        Positioned.fill(
          child:
              widget.gestureItemBuilder?.call(
                context,
                widget.pageIndex,
                context.watch<_StoryStackController>().value,
              ) ??
              const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _Gestures extends StatelessWidget {
  const _Gestures({required this.animationController});

  final AnimationController? animationController;

  /// Resumes the indicator from wherever it was paused, rather than
  /// restarting it — [AnimationController.forward] (called with no
  /// `from:`) automatically scales the remaining play time to the
  /// fraction of progress left, so this isn't "pause and replay the full
  /// duration", it's "pause and continue with the correct remaining
  /// duration".
  void _resume() {
    if (storyImageLoadingController.value != StoryImageLoadingState.loading) {
      animationController!.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Listener(
            // Listener's pointer callbacks fire for every pointer that
            // touches this widget regardless of which gesture recognizer
            // ends up winning the arena (a tap here, a vertical drag for
            // pull-to-dismiss elsewhere, a swipe on the PageView, ...).
            // Tying pause/resume to onTapDown/onTapUp alone meant a tap
            // that turned into a drag would fire onTapCancel instead of
            // onTapUp, leaving the indicator paused forever.
            onPointerDown: (_) => animationController!.stop(),
            onPointerUp: (_) => _resume(),
            onPointerCancel: (_) => _resume(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                animationController!.forward(from: 0);
                context.read<_StoryStackController>().decrement();
              },
            ),
          ),
        ),
        Expanded(
          child: Listener(
            onPointerDown: (_) => animationController!.stop(),
            onPointerUp: (_) => _resume(),
            onPointerCancel: (_) => _resume(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.read<_StoryStackController>().increment(
                  restartAnimation: () => animationController!.forward(from: 0),
                  completeAnimation: () => animationController!.value = 1,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Indicators extends StatefulWidget {
  const _Indicators({
    required this.animationController,
    required this.storyLength,
    required this.isCurrentPage,
    required this.isPaging,
    required this.padding,
    required this.indicatorUnvisitedColor,
    required this.indicatorVisitedColor,
    required this.indicatorHeight,
    required this.indicatorRadius,
    required this.indicatorAnimationController,
  });
  final int storyLength;
  final AnimationController? animationController;
  final EdgeInsetsGeometry padding;
  final bool isCurrentPage;
  final bool isPaging;
  final Color indicatorVisitedColor;
  final Color indicatorUnvisitedColor;
  final double indicatorHeight;
  final double indicatorRadius;
  final ValueNotifier<IndicatorAnimationCommand>? indicatorAnimationController;

  @override
  State<_Indicators> createState() => _IndicatorsState();
}

class _IndicatorsState extends State<_Indicators> {
  late Animation<double> indicatorAnimation;

  @override
  void initState() {
    super.initState();
    if (storyImageLoadingController.value != StoryImageLoadingState.loading) {
      widget.animationController!.forward();
    }
    indicatorAnimation =
        Tween(begin: 0.0, end: 1.0).animate(widget.animationController!)
          ..addListener(() {
            setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    final int currentStoryIndex = context.watch<_StoryStackController>().value;
    final bool isStoryEnded = context.watch<_StoryLimitController>().value;
    if (!widget.isCurrentPage && widget.isPaging) {
      widget.animationController!.stop();
    }
    if (!widget.isCurrentPage &&
        !widget.isPaging &&
        widget.animationController!.value != 0) {
      widget.animationController!.value = 0;
    }
    if (widget.isCurrentPage &&
        !widget.animationController!.isAnimating &&
        !isStoryEnded &&
        storyImageLoadingController.value != StoryImageLoadingState.loading) {
      widget.animationController!.forward(from: 0);
    }
    return Padding(
      padding: widget.padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          widget.storyLength,
          (index) => _Indicator(
            index: index,
            indicatorHeight: widget.indicatorHeight,
            indicatorRadius: widget.indicatorRadius,
            value: (index == currentStoryIndex)
                ? indicatorAnimation.value
                : (index > currentStoryIndex)
                ? 0
                : 1,
            indicatorVisitedColor: widget.indicatorVisitedColor,
            indicatorUnvisitedColor: widget.indicatorUnvisitedColor,
          ),
        ),
      ),
    );
  }

  // animationController is owned and disposed by _StoryPageBuilderState
  // (which created it and passes it down) — not here.
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.index,
    required this.value,
    required this.indicatorVisitedColor,
    required this.indicatorUnvisitedColor,
    required this.indicatorHeight,
    required this.indicatorRadius,
  });
  final int index;
  final double value;
  final Color indicatorVisitedColor;
  final Color indicatorUnvisitedColor;
  final double indicatorHeight;
  final double indicatorRadius;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: (index == 0) ? 0 : 4),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(indicatorRadius)),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: indicatorUnvisitedColor,
            valueColor: AlwaysStoppedAnimation<Color>(indicatorVisitedColor),
            minHeight: indicatorHeight,
          ),
        ),
      ),
    );
  }
}

/// Notify current stack index
class _StoryStackController extends ValueNotifier<int> {
  _StoryStackController({
    required this.storyLength,
    required this.onPageForward,
    required this.onPageBack,
    int initialStoryIndex = 0,
  }) : super(initialStoryIndex);
  final int storyLength;
  final VoidCallback onPageForward;
  final VoidCallback onPageBack;

  int get limitIndex => storyLength - 1;

  void increment({
    VoidCallback? restartAnimation,
    VoidCallback? completeAnimation,
  }) {
    if (value == limitIndex) {
      completeAnimation?.call();
      onPageForward();
    } else {
      value++;
      restartAnimation?.call();
    }
  }

  void decrement() {
    if (value == 0) {
      onPageBack();
    } else {
      value--;
    }
  }
}

class _StoryLimitController extends ValueNotifier<bool> {
  _StoryLimitController() : super(false);

  void onPageLimitReached(VoidCallback? callback) {
    if (!value) {
      callback?.call();
      value = true;
    }
  }
}
