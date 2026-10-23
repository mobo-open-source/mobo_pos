import 'package:flutter/services.dart';

/// Strips a leading `http://` or `https://` from a server-address field and
/// reports it through [onProtocolDetected], so the protocol can be shown in a
/// separate dropdown.
///
/// Runs as a [TextInputFormatter] rather than as a controller listener. A
/// listener that assigns `controller.text` re-enters the notification it is
/// handling and resets the caret; doing the same work here keeps the edit
/// atomic and lets the caret be moved by exactly the number of characters
/// removed instead of being forced to the end of the field.
class UrlProtocolFormatter extends TextInputFormatter {
  UrlProtocolFormatter({required this.onProtocolDetected});

  final void Function(String protocol) onProtocolDetected;

  static final RegExp _protocol =
      RegExp(r'^\s*(https?://)', caseSensitive: false);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final match = _protocol.firstMatch(newValue.text);
    if (match == null) return newValue;

    onProtocolDetected(match.group(1)!.toLowerCase());

    final removed = match.end;
    final text = newValue.text.substring(removed);
    final baseOffset =
        (newValue.selection.baseOffset - removed).clamp(0, text.length);
    final extentOffset =
        (newValue.selection.extentOffset - removed).clamp(0, text.length);

    return TextEditingValue(
      text: text,
      selection: newValue.selection.isCollapsed
          ? TextSelection.collapsed(offset: baseOffset)
          : TextSelection(baseOffset: baseOffset, extentOffset: extentOffset),
      composing: TextRange.empty,
    );
  }
}
