import 'dart:typed_data';

/// Text alignment for a printed line.
enum PosAlign { left, center, right }

/// Minimal, dependency-free ESC/POS command builder.
///
/// It produces the raw byte stream understood by virtually every thermal
/// receipt printer (ESC/POS is the de-facto standard, and the Landi M20's
/// built-in head speaks it as well). Keeping this hand-written avoids pulling
/// in an external `esc_pos_utils`-style package (whose published versions do
/// not match the ones commonly quoted and add transport code we do not need —
/// transport here is handled by [PrinterService]).
///
/// The same byte stream is used for both transports:
///  * network printers — written straight to a TCP socket;
///  * the Landi built-in printer — handed to the native side over a
///    [MethodChannel] which forwards it to the device SDK.
class EscPosBuilder {
  EscPosBuilder({this.charsPerLine = 32});

  /// Characters that fit on one line for the selected paper width.
  /// 58 mm paper ≈ 32 chars, 80 mm paper ≈ 48 chars (Font A).
  final int charsPerLine;

  final List<int> _bytes = <int>[];

  // --- ESC/POS control codes -------------------------------------------------
  static const int _esc = 0x1B;
  static const int _gs = 0x1D;
  static const int _lf = 0x0A;

  /// Resolve the printable width for a given paper size in millimetres.
  static int charsForPaperWidth(int paperWidthMm) =>
      paperWidthMm >= 80 ? 48 : 32;

  /// `ESC @` — reset the printer to its power-on defaults.
  EscPosBuilder reset() {
    _bytes.addAll(<int>[_esc, 0x40]);
    return this;
  }

  /// `ESC a n` — set justification.
  EscPosBuilder _setAlign(PosAlign align) {
    final int n = switch (align) {
      PosAlign.left => 0,
      PosAlign.center => 1,
      PosAlign.right => 2,
    };
    _bytes.addAll(<int>[_esc, 0x61, n]);
    return this;
  }

  /// `ESC E n` — emphasised (bold) on/off.
  EscPosBuilder _setBold(bool on) {
    _bytes.addAll(<int>[_esc, 0x45, on ? 1 : 0]);
    return this;
  }

  /// `GS ! n` — character size. Bits 4-7 = width, bits 0-3 = height.
  EscPosBuilder _setSize({bool doubleWidth = false, bool doubleHeight = false}) {
    int n = 0;
    if (doubleWidth) n |= 0x10;
    if (doubleHeight) n |= 0x01;
    _bytes.addAll(<int>[_gs, 0x21, n]);
    return this;
  }

  /// Print a single line of [text] with the given styling, followed by LF.
  ///
  /// [text] is truncated to fit the paper width when it is not enlarged.
  EscPosBuilder text(
    String text, {
    PosAlign align = PosAlign.left,
    bool bold = false,
    bool doubleWidth = false,
    bool doubleHeight = false,
  }) {
    _setAlign(align);
    _setBold(bold);
    if (doubleWidth || doubleHeight) {
      _setSize(doubleWidth: doubleWidth, doubleHeight: doubleHeight);
    }

    final int maxChars =
        doubleWidth ? (charsPerLine ~/ 2) : charsPerLine;
    final String line =
        text.length > maxChars ? text.substring(0, maxChars) : text;
    _bytes.addAll(_encode(line));
    _bytes.add(_lf);

    // Restore defaults so the next line is not affected.
    if (doubleWidth || doubleHeight) _setSize();
    _setBold(false);
    return this;
  }

  /// Print a left/right justified row, e.g. an item name and its price.
  ///
  /// [left] is left-aligned, [right] is right-aligned, and the gap between them
  /// is padded with spaces so the row exactly fills [charsPerLine]. When the
  /// two strings would collide the left side is truncated.
  EscPosBuilder leftRight(String left, String right, {bool bold = false}) {
    _setAlign(PosAlign.left);
    _setBold(bold);

    final int space = charsPerLine - right.length;
    String leftPart = left;
    if (leftPart.length > space - 1 && space > 1) {
      leftPart = leftPart.substring(0, space - 1);
    }
    final int padding = charsPerLine - leftPart.length - right.length;
    final String line =
        leftPart + (padding > 0 ? ' ' * padding : ' ') + right;

    _bytes.addAll(_encode(
        line.length > charsPerLine ? line.substring(0, charsPerLine) : line));
    _bytes.add(_lf);
    _setBold(false);
    return this;
  }

  /// Print a three-column item row: name, quantity, amount.
  EscPosBuilder itemRow(String name, String qty, String amount) {
    // Reserve fixed space for qty + amount, name takes the remainder.
    final String tail = '${qty.padLeft(4)} ${amount.padLeft(9)}';
    final int nameWidth = charsPerLine - tail.length;
    String namePart = name;
    if (nameWidth <= 0) {
      return text('$name $tail');
    }
    if (namePart.length > nameWidth) {
      namePart = namePart.substring(0, nameWidth);
    }
    return text(namePart.padRight(nameWidth) + tail);
  }

  /// A horizontal rule made of dashes across the full width.
  EscPosBuilder hr([String char = '-']) => text(char * charsPerLine);

  /// Feed [lines] blank lines.
  EscPosBuilder feed([int lines = 1]) {
    for (int i = 0; i < lines; i++) {
      _bytes.add(_lf);
    }
    return this;
  }

  /// `GS V m` — cut the paper. Uses a partial cut by default.
  EscPosBuilder cut({bool partial = true}) {
    _bytes.addAll(<int>[_gs, 0x56, partial ? 0x01 : 0x00]);
    return this;
  }

  /// The accumulated command stream.
  Uint8List build() => Uint8List.fromList(_bytes);

  /// Encode text for the printer. Receipt printers default to a single-byte
  /// code page; latin1 covers the common Western/currency glyphs, and any
  /// character outside it is replaced with '?' rather than emitting invalid
  /// multi-byte sequences.
  List<int> _encode(String value) {
    return value.runes
        .map((int rune) => rune <= 0xFF ? rune : 0x3F /* ? */)
        .toList(growable: false);
  }
}
