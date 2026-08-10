import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'esc_pos_builder.dart';
import 'receipt_data.dart';

/// How receipt content reaches the printer.
enum PrinterMode {
  /// The Landi/Newland M20 built-in thermal printer, driven through the native
  /// NSDK core over a [MethodChannel] (receipt is sent as text and rendered to
  /// a bitmap on the device).
  builtin,

  /// A standalone network receipt printer listening for raw ESC/POS on a TCP
  /// port (usually 9100). Handled entirely in Dart via [Socket].
  network,
}

/// Immutable snapshot of the user's printer configuration.
class PrinterConfig {
  const PrinterConfig({
    required this.enabled,
    required this.mode,
    required this.address,
    required this.port,
    required this.paperWidthMm,
    required this.autoPrint,
  });

  final bool enabled;
  final PrinterMode mode;
  final String address;
  final int port;
  final int paperWidthMm; // 58 or 80
  final bool autoPrint;

  PrinterConfig copyWith({
    bool? enabled,
    PrinterMode? mode,
    String? address,
    int? port,
    int? paperWidthMm,
    bool? autoPrint,
  }) {
    return PrinterConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      address: address ?? this.address,
      port: port ?? this.port,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      autoPrint: autoPrint ?? this.autoPrint,
    );
  }
}

/// Outcome of a print attempt.
class PrintResult {
  const PrintResult(this.success, [this.message = '']);

  final bool success;
  final String message;
}

/// Formats receipts and delivers them to either the Landi/Newland M20 built-in
/// printer (native NSDK channel, bitmap) or a networked ESC/POS printer (TCP).
///
/// Stateless service class (matches [StorageService] style): reads config from
/// [SharedPreferences] on demand.
class PrinterService {
  /// Native side registered in `MainActivity.configureFlutterEngine`.
  static const MethodChannel _channel =
      MethodChannel('com.cybrosys.mobo_pos/printer');

  // --- SharedPreferences keys ------------------------------------------------
  static const String _kEnabled = 'printer_enabled';
  static const String _kMode = 'printer_mode';
  static const String _kAddress = 'printer_address';
  static const String _kPort = 'printer_port';
  static const String _kPaperWidth = 'printer_paper_width';
  static const String _kAutoPrint = 'printer_auto_print';

  // --- Configuration ---------------------------------------------------------

  Future<PrinterConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterConfig(
      enabled: prefs.getBool(_kEnabled) ?? false,
      mode: (prefs.getString(_kMode) ?? 'builtin') == 'network'
          ? PrinterMode.network
          : PrinterMode.builtin,
      address: prefs.getString(_kAddress) ?? '192.168.1.100',
      port: prefs.getInt(_kPort) ?? 9100,
      paperWidthMm: prefs.getInt(_kPaperWidth) ?? 58,
      // Default ON: once printing is enabled, receipts print automatically
      // when Odoo shows the receipt after a completed payment.
      autoPrint: prefs.getBool(_kAutoPrint) ?? true,
    );
  }

  Future<void> saveConfig(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, config.enabled);
    await prefs.setString(
        _kMode, config.mode == PrinterMode.network ? 'network' : 'builtin');
    await prefs.setString(_kAddress, config.address);
    await prefs.setInt(_kPort, config.port);
    await prefs.setInt(_kPaperWidth, config.paperWidthMm);
    await prefs.setBool(_kAutoPrint, config.autoPrint);
  }

  /// Whether a built-in printer is present and initialised on this device.
  Future<bool> isBuiltinAvailable() async {
    try {
      final bool? available =
          await _channel.invokeMethod<bool>('isBuiltinAvailable');
      return available ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // --- Printing --------------------------------------------------------------

  /// Print [data] using the saved config.
  Future<PrintResult> printReceipt(ReceiptData data) async {
    final PrinterConfig config = await loadConfig();
    if (!config.enabled) {
      return const PrintResult(false, 'Printing is disabled in settings');
    }
    if (config.mode == PrinterMode.network) {
      final bytes = _buildReceiptEscPos(data, config.paperWidthMm);
      return _sendNetwork(bytes, config.address, config.port);
    }
    final text = _buildReceiptText(data, config.paperWidthMm);
    return _sendBuiltinText(text, config.paperWidthMm);
  }

  /// Print a short self-test receipt to verify connectivity/config.
  Future<PrintResult> testPrint() async {
    final PrinterConfig config = await loadConfig();
    final int chars = EscPosBuilder.charsForPaperWidth(config.paperWidthMm);
    final String modeLabel =
        config.mode == PrinterMode.network ? 'Network' : 'Built-in';

    if (config.mode == PrinterMode.network) {
      final b = EscPosBuilder(charsPerLine: chars)
        ..reset()
        ..text('mobo POS',
            align: PosAlign.center, bold: true, doubleWidth: true)
        ..text('Printer test', align: PosAlign.center)
        ..hr()
        ..leftRight('Mode', modeLabel)
        ..leftRight('Paper', '${config.paperWidthMm} mm')
        ..hr()
        ..text('If you can read this, printing works.',
            align: PosAlign.center)
        ..feed(3)
        ..cut();
      return _sendNetwork(b.build(), config.address, config.port);
    }

    final String text = [
      _center('mobo POS', chars),
      _center('Printer test', chars),
      '-' * chars,
      _leftRight('Mode', modeLabel, chars),
      _leftRight('Paper', '${config.paperWidthMm} mm', chars),
      '-' * chars,
      _center('If you can read this,', chars),
      _center('printing works.', chars),
    ].join('\n');
    return _sendBuiltinText(text, config.paperWidthMm);
  }

  // --- Receipt formatting ----------------------------------------------------

  /// Build a plain-text receipt for the built-in (bitmap) printer. Odoo's own
  /// rendered layout is preferred when available; otherwise a layout is built
  /// from the structured fields.
  String _buildReceiptText(ReceiptData data, int paperWidthMm) {
    if (data.rawText.trim().isNotEmpty) return data.rawText;

    final int chars = EscPosBuilder.charsForPaperWidth(paperWidthMm);
    final StringBuffer b = StringBuffer();
    if (data.storeName.isNotEmpty) b.writeln(_center(data.storeName, chars));
    for (final line in data.headerLines) {
      b.writeln(_center(line, chars));
    }
    b.writeln('-' * chars);
    for (final line in data.lines) {
      final qtyPrice = [
        if (line.qty.isNotEmpty) line.qty,
        if (line.price.isNotEmpty) line.price,
      ].join(' x ');
      b.writeln(_leftRight(line.name, qtyPrice, chars));
    }
    b.writeln('-' * chars);
    if (data.total.isNotEmpty) b.writeln(_leftRight('TOTAL', data.total, chars));
    for (final payment in data.payments) {
      b.writeln(_leftRight(payment.name, payment.amount, chars));
    }
    if (data.change.isNotEmpty) {
      b.writeln(_leftRight('Change', data.change, chars));
    }
    for (final line in data.footerLines) {
      b.writeln(_center(line, chars));
    }
    return b.toString();
  }

  String _center(String s, int width) {
    if (s.length >= width) return s;
    final int pad = (width - s.length) ~/ 2;
    return '${' ' * pad}$s';
  }

  String _leftRight(String left, String right, int width) {
    final int space = width - left.length - right.length;
    if (space > 0) return '$left${' ' * space}$right';
    return '$left $right';
  }

  /// Build the ESC/POS byte stream for a full order receipt (network path).
  Uint8List _buildReceiptEscPos(ReceiptData data, int paperWidthMm) {
    final int chars = EscPosBuilder.charsForPaperWidth(paperWidthMm);
    final EscPosBuilder b = EscPosBuilder(charsPerLine: chars)..reset();

    if (data.hasStructuredContent) {
      if (data.storeName.isNotEmpty) {
        b.text(data.storeName,
            align: PosAlign.center, bold: true, doubleWidth: true);
      }
      for (final line in data.headerLines) {
        b.text(line, align: PosAlign.center);
      }
      b.hr();
      for (final line in data.lines) {
        b.itemRow(line.name, line.qty, line.price);
      }
      b.hr();
      if (data.total.isNotEmpty) b.leftRight('TOTAL', data.total, bold: true);
      for (final payment in data.payments) {
        b.leftRight(payment.name, payment.amount);
      }
      if (data.change.isNotEmpty) b.leftRight('Change', data.change);
      if (data.footerLines.isNotEmpty) {
        b.feed();
        for (final line in data.footerLines) {
          b.text(line, align: PosAlign.center);
        }
      }
    } else {
      for (final line in data.rawText.split('\n')) {
        b.text(line);
      }
    }

    b
      ..feed(3)
      ..cut();
    return b.build();
  }

  // --- Transports ------------------------------------------------------------

  /// Raw ESC/POS over TCP (e.g. a networked 80 mm printer at :9100).
  Future<PrintResult> _sendNetwork(
      Uint8List bytes, String address, int port) async {
    if (address.trim().isEmpty) {
      return const PrintResult(false, 'Printer IP address is not set');
    }
    Socket? socket;
    try {
      socket = await Socket.connect(address, port,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return const PrintResult(true, 'Sent to network printer');
    } on SocketException catch (e) {
      return PrintResult(false, 'Could not reach $address:$port — ${e.message}');
    } catch (e) {
      return PrintResult(false, 'Network print failed: $e');
    } finally {
      await socket?.close();
    }
  }

  /// Hand the receipt text to the native NSDK printer channel.
  Future<PrintResult> _sendBuiltinText(String text, int paperWidthMm) async {
    try {
      final bool? ok = await _channel.invokeMethod<bool>('printText', {
        'text': text,
        'paperWidth': paperWidthMm,
      });
      return (ok ?? false)
          ? const PrintResult(true, 'Sent to built-in printer')
          : const PrintResult(false, 'Built-in printer rejected the job');
    } on MissingPluginException {
      return const PrintResult(
          false, 'Built-in printer channel is unavailable on this platform');
    } on PlatformException catch (e) {
      return PrintResult(false, e.message ?? 'Built-in print failed');
    }
  }
}
