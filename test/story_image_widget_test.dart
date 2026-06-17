import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_stack/story_image.dart';

import 'test_utils.dart';

/// An [ImageProvider] whose resolution is controlled manually via
/// [completer], so tests can deterministically observe the moment between
/// "still loading" and "available" instead of racing a real decode.
class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  _PendingImageProvider(this.completer);

  final Completer<ImageInfo> completer;

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PendingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(completer.future);
  }
}

Future<ui.Image> _decodeTestImage() async {
  final codec = await ui.instantiateImageCodec(kTransparentImageBytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  testWidgets('renders an Image with the given image provider', (tester) async {
    final imageProvider = testAvatarImageProvider();
    await tester.pumpWidget(
      wrapWithApp(
        StoryImage(key: const ValueKey('img'), imageProvider: imageProvider),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, imageProvider);
  });

  testWidgets('forwards layout/appearance properties to the inner Image', (
    tester,
  ) async {
    final imageProvider = testAvatarImageProvider();
    await tester.pumpWidget(
      wrapWithApp(
        StoryImage(
          key: const ValueKey('img'),
          imageProvider: imageProvider,
          width: 40,
          height: 50,
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          color: Colors.red,
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 40);
    expect(image.height, 50);
    expect(image.fit, BoxFit.fitWidth);
    expect(image.alignment, Alignment.topCenter);
    expect(image.color, Colors.red);
  });

  testWidgets(
    'sets storyImageLoadingController to loading then available as the '
    'image resolves',
    (tester) async {
      // Reset to a known state; other tests/widgets share this global.
      storyImageLoadingController.value = StoryImageLoadingState.available;

      // Image decoding is real engine work and can't complete inside the
      // FakeAsync zone testWidgets normally runs in — without runAsync()
      // this future never resolves and the test hangs until it times out.
      final decodedImage = (await tester.runAsync(_decodeTestImage))!;
      final completer = Completer<ImageInfo>();

      await tester.pumpWidget(
        wrapWithApp(
          StoryImage(
            key: const ValueKey('img'),
            imageProvider: _PendingImageProvider(completer),
          ),
        ),
      );

      // The provider hasn't resolved yet, so the controller should still
      // report loading.
      expect(storyImageLoadingController.value, StoryImageLoadingState.loading);

      completer.complete(ImageInfo(image: decodedImage, scale: 1));
      await tester.pumpAndSettle();

      expect(
        storyImageLoadingController.value,
        StoryImageLoadingState.available,
      );
    },
  );

  testWidgets(
    're-resolves and updates loading state when imageProvider changes',
    (tester) async {
      storyImageLoadingController.value = StoryImageLoadingState.available;

      final decodedImage = (await tester.runAsync(_decodeTestImage))!;
      final completer1 = Completer<ImageInfo>();
      final completer2 = Completer<ImageInfo>();

      await tester.pumpWidget(
        wrapWithApp(
          StoryImage(
            key: const ValueKey('img'),
            imageProvider: _PendingImageProvider(completer1),
          ),
        ),
      );
      expect(storyImageLoadingController.value, StoryImageLoadingState.loading);

      completer1.complete(ImageInfo(image: decodedImage, scale: 1));
      await tester.pumpAndSettle();
      expect(
        storyImageLoadingController.value,
        StoryImageLoadingState.available,
      );

      // Same key, but a different provider instance: didUpdateWidget should
      // detect the change and re-resolve instead of keeping the stale
      // "available" state around from the previous image.
      await tester.pumpWidget(
        wrapWithApp(
          StoryImage(
            key: const ValueKey('img'),
            imageProvider: _PendingImageProvider(completer2),
          ),
        ),
      );
      expect(storyImageLoadingController.value, StoryImageLoadingState.loading);

      completer2.complete(ImageInfo(image: decodedImage, scale: 1));
      await tester.pumpAndSettle();
      expect(
        storyImageLoadingController.value,
        StoryImageLoadingState.available,
      );

      // The old provider's stream listener should have been detached, so
      // completing it (late) afterwards must not throw or affect anything.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposes without throwing', (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        StoryImage(
          key: const ValueKey('img'),
          imageProvider: testAvatarImageProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });
}
