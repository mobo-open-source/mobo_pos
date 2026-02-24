import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_pos/core/image_utils.dart';

void main() {
  group('ImageUtils.isValidImage', () {
    test('returns true for valid PNG', () {
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
      expect(ImageUtils.isValidImage(pngBytes), isTrue);
    });

    test('returns true for valid JPEG', () {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
      expect(ImageUtils.isValidImage(jpegBytes), isTrue);
    });

    test('returns true for valid GIF', () {
      final gifBytes = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0]);
      expect(ImageUtils.isValidImage(gifBytes), isTrue);
    });

    test('returns true for valid WebP', () {
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0, 0, 0, 0,
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      expect(ImageUtils.isValidImage(webpBytes), isTrue);
    });

    test('returns false for null bytes', () {
      expect(ImageUtils.isValidImage(null), isFalse);
    });

    test('returns false for empty bytes', () {
      expect(ImageUtils.isValidImage(Uint8List(0)), isFalse);
    });

    test('returns false for corrupted data', () {
      final corruptedBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      expect(ImageUtils.isValidImage(corruptedBytes), isFalse);
    });

    test('returns false for short data', () {
      final shortBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      expect(ImageUtils.isValidImage(shortBytes), isFalse);
    });
  });
}
