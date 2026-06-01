import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../platform/file_storage.dart';

/// Platform-aware thumbnail image.
/// Reads from OPFS on web, from disk on native, via [FileStorage.readBytes].
/// Shows [placeholder] (default: empty SizedBox) if file is missing.
class ThumbnailImage extends StatefulWidget {
  final String path;
  final BoxFit fit;
  final Widget? placeholder;

  const ThumbnailImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  State<ThumbnailImage> createState() => _ThumbnailImageState();
}

class _ThumbnailImageState extends State<ThumbnailImage> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = FileStorage.readBytes(widget.path);
  }

  @override
  void didUpdateWidget(ThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      setState(() {
        _future = FileStorage.readBytes(widget.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.hasData && snap.data != null) {
          return Image.memory(snap.data!, fit: widget.fit);
        }
        return widget.placeholder ?? const SizedBox.shrink();
      },
    );
  }
}
