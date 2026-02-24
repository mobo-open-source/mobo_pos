import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Service for handling low-level network operations and database discovery.
class NetworkService {
  /// Returns a custom HTTP client that bypasses SSL certificate verification.
  static http.BaseClient getClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  /// Fetches the list of available databases from the given Odoo server URL.
  Future<List<String>> fetchDatabaseList(String url) async {
    try {
      String normalizedUrl = url.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      // Create custom HTTP client that bypasses SSL certificate verification
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final request =
          await httpClient.postUrl(Uri.parse('$normalizedUrl/web/database/list'));
      request.headers.set('Content-Type', 'application/json');
      request.write(
          jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}, 'id': 1}));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      httpClient.close();
      final jsonResponse = jsonDecode(responseBody);
      if (jsonResponse['result'] is List) {
        return (jsonResponse['result'] as List).map((db) => db.toString()).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
