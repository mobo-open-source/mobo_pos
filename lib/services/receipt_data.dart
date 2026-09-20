/// A single line item on a receipt.
class ReceiptLine {
  ReceiptLine({
    required this.name,
    required this.qty,
    required this.price,
  });

  final String name;
  final String qty;
  final String price;

  factory ReceiptLine.fromJson(Map<dynamic, dynamic> json) => ReceiptLine(
        name: (json['name'] ?? '').toString(),
        qty: (json['qty'] ?? '').toString(),
        price: (json['price'] ?? json['price_subtotal'] ?? '').toString(),
      );
}

/// A payment tender line (e.g. "Cash  20.00").
class ReceiptPayment {
  ReceiptPayment({required this.name, required this.amount});

  final String name;
  final String amount;

  factory ReceiptPayment.fromJson(Map<dynamic, dynamic> json) => ReceiptPayment(
        name: (json['name'] ?? '').toString(),
        amount: (json['amount'] ?? '').toString(),
      );
}

/// Structured receipt content extracted from the Odoo POS receipt in the
/// WebView. All fields are best-effort: the Odoo receipt DOM varies between
/// versions, so [rawText] (the receipt's rendered `innerText`) is always
/// captured as a robust fallback and is used when [lines] could not be parsed.
class ReceiptData {
  ReceiptData({
    this.storeName = '',
    this.headerLines = const <String>[],
    this.lines = const <ReceiptLine>[],
    this.total = '',
    this.payments = const <ReceiptPayment>[],
    this.change = '',
    this.footerLines = const <String>[],
    this.rawText = '',
  });

  final String storeName;
  final List<String> headerLines;
  final List<ReceiptLine> lines;
  final String total;
  final List<ReceiptPayment> payments;
  final String change;
  final List<String> footerLines;
  final String rawText;

  /// True when we have structured line items to format nicely; otherwise the
  /// caller should fall back to printing [rawText].
  bool get hasStructuredContent => lines.isNotEmpty;

  factory ReceiptData.fromJson(Map<dynamic, dynamic> json) {
    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.map((dynamic e) => e.toString()).toList();
      }
      return const <String>[];
    }

    return ReceiptData(
      storeName: (json['storeName'] ?? '').toString(),
      headerLines: stringList(json['headerLines']),
      lines: (json['lines'] is List)
          ? (json['lines'] as List)
              .whereType<Map>()
              .map(ReceiptLine.fromJson)
              .toList()
          : const <ReceiptLine>[],
      total: (json['total'] ?? '').toString(),
      payments: (json['payments'] is List)
          ? (json['payments'] as List)
              .whereType<Map>()
              .map(ReceiptPayment.fromJson)
              .toList()
          : const <ReceiptPayment>[],
      change: (json['change'] ?? '').toString(),
      footerLines: stringList(json['footerLines']),
      rawText: (json['rawText'] ?? '').toString(),
    );
  }
}
