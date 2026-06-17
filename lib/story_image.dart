import 'package:flutter/material.dart';

/// StoryImage
enum StoryImageLoadingState { loading, available }

class StoryImageLoadingController
    extends ValueNotifier<StoryImageLoadingState> {
  StoryImageLoadingController._() : super(StoryImageLoadingState.available);
}

final storyImageLoadingController = StoryImageLoadingController._();

class StoryImage extends StatefulWidget {
  const StoryImage({
    required super.key,
    required this.imageProvider,
    this.loadingBuilder,
    this.frameBuilder,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.low,
  });

  final ImageProvider<Object> imageProvider;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final double? width;
  final double? height;
  final Color? color;
  final Animation<double>? opacity;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final bool isAntiAlias;
  final FilterQuality filterQuality;

  @override
  State<StoryImage> createState() => _StoryImageState();
}

class _StoryImageState extends State<StoryImage> {
  late final ImageStreamListener imageStreamListener;
  ImageStream? imageStream;

  @override
  void initState() {
    super.initState();
    imageStreamListener = ImageStreamListener((image, synchronousCall) {
      storyImageLoadingController.value = StoryImageLoadingState.available;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Image resolution depends on inherited widgets (MediaQuery, etc. via
    // createLocalImageConfiguration), which aren't fully available until
    // didChangeDependencies — resolving in initState would miss them.
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant StoryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageProvider != oldWidget.imageProvider) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    storyImageLoadingController.value = StoryImageLoadingState.loading;
    final oldImageStream = imageStream;
    imageStream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (imageStream!.key != oldImageStream?.key) {
      oldImageStream?.removeListener(imageStreamListener);
      imageStream!.addListener(imageStreamListener);
    }
  }

  @override
  void dispose() {
    // Without this, the listener stays attached to the resolved image
    // stream after this widget is gone, which can keep updating the
    // (global) storyImageLoadingController from a disposed StoryImage.
    imageStream?.removeListener(imageStreamListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: widget.imageProvider,
      frameBuilder: widget.frameBuilder,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: widget.errorBuilder,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.excludeFromSemantics,
      width: widget.width,
      height: widget.height,
      color: widget.color,
      opacity: widget.opacity,
      colorBlendMode: widget.colorBlendMode,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      centerSlice: widget.centerSlice,
      matchTextDirection: widget.matchTextDirection,
      gaplessPlayback: widget.gaplessPlayback,
      isAntiAlias: widget.isAntiAlias,
      filterQuality: widget.filterQuality,
    );
  }
}
