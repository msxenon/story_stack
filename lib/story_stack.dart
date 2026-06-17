library story_stack;

import 'package:story_stack/story_stack_delegate.dart';

export 'story_page_view.dart';
export 'story_image.dart';
export 'story_stack_delegate.dart';
export 'story_user_circle.dart';
export 'story_circles_list.dart';

/// App-wide configuration for story_stack widgets.
///
/// [StoryUserCircle] and [StoryCirclesList] both accept a `delegate:`
/// parameter for one-off overrides; when left unset (`null`), they fall
/// back to [StoryStack.delegate]. Set this once, e.g. in `main()`, to
/// change the default behavior (such as how max story segments are
/// calculated) everywhere in the app without passing `delegate:` to every
/// widget instance.
class StoryStack {
  static StoryStackDelegate delegate = const DefaultStoryStackDelegate();
}
