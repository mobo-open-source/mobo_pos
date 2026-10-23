import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImageUtils {
  /// Base64 payload of a binary field value from `read`/`search_read`.
  /// Odoo 20 returns binary fields as `{content, size, filename}`; earlier
  /// versions return the base64 string itself. Returns '' when unset.
  static String base64Of(dynamic value) {
    if (value is String) return value;
    if (value is Map && value['content'] is String) {
      return value['content'] as String;
    }
    return '';
  }

  /// Odoo (16+) generates an SVG "initials" avatar for users without a photo
  /// and stores it as `image_1920`, so profile images can be SVG.
  static bool isSvg(Uint8List? bytes) {
    if (bytes == null || bytes.length < 5) return false;
    final head = String.fromCharCodes(bytes.take(256)).trimLeft();
    return head.startsWith('<svg') || head.startsWith('<?xml');
  }

  /// Drop-in for [Image.memory] that also renders SVG bytes.
  static Widget memory(
    Uint8List bytes, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    if (isSvg(bytes)) {
      return SvgPicture.memory(bytes, width: width, height: height, fit: fit);
    }
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }

  /// Checks if the provided bytes represent a valid image format (PNG, JPEG, GIF, WebP).
  static bool isValidImage(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return false;
    if (isSvg(bytes)) return true;

    // Minimum bytes needed to check magic numbers
    if (bytes.length < 8) return false;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return true;
    }

    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return true;
    }

    // WebP: 52 49 46 46 (RIFF) ... 57 45 42 50 (WEBP)
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }
}
