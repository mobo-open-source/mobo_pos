import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

class FullImageScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String? title;
  final String? imageName;

  const FullImageScreen({
    super.key,
    required this.imageBytes,
    this.title,
    this.imageName,
  });

  @override
  State<FullImageScreen> createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  static const double _zoomScale = 2.5;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final matrix = _transformationController.value;
    if (matrix != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else if (_doubleTapDetails != null) {
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(
            -position.dx * (_zoomScale - 1), -position.dy * (_zoomScale - 1))
        ..scale(_zoomScale);
    }
  }

  String _getDisplayTitle() {
    if (widget.imageName != null && widget.imageName!.isNotEmpty) {
      return widget.imageName!;
    }
    return widget.title ?? 'Image';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = _getDisplayTitle();

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          displayTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: HugeIcon(icon:
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        elevation: 0,
      ),
      body: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: SizedBox.expand(
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 5.0,
            boundaryMargin: EdgeInsets.zero,
            constrained: true,
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.error,
                  color: isDark ? Colors.red[300] : Colors.red,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
