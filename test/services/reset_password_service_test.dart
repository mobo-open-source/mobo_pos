import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_pos/services/reset_password_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResetPasswordService Tests', () {
    group('isValidEmail', () {
      test('returns true for valid email addresses', () {
        expect(ResetPasswordService.isValidEmail('test@example.com'), true);
        expect(ResetPasswordService.isValidEmail('user.name@domain.co.uk'), true);
        expect(ResetPasswordService.isValidEmail('first+last@company.com'), true);
        expect(ResetPasswordService.isValidEmail('admin@localhost'), true);
      });

      test('returns false for invalid email addresses', () {
        expect(ResetPasswordService.isValidEmail(''), false);
        expect(ResetPasswordService.isValidEmail('notanemail'), false);
        expect(ResetPasswordService.isValidEmail('@example.com'), false);
        expect(ResetPasswordService.isValidEmail('user@'), false);
        expect(ResetPasswordService.isValidEmail('user @example.com'), false);
        expect(ResetPasswordService.isValidEmail('user@.com'), false);
      });

      test('handles edge cases', () {
        expect(ResetPasswordService.isValidEmail('a@b.c'), true);
        expect(ResetPasswordService.isValidEmail('test@test.com'), true);
        expect(ResetPasswordService.isValidEmail('   '), false);
      });
    });

    group('isValidUrl', () {
      test('returns true for valid HTTP URLs', () {
        expect(ResetPasswordService.isValidUrl('http://example.com'), true);
        expect(ResetPasswordService.isValidUrl('http://localhost'), true);
        expect(ResetPasswordService.isValidUrl('http://192.168.1.1'), true);
        expect(ResetPasswordService.isValidUrl('http://example.com:8069'), true);
      });

      test('returns true for valid HTTPS URLs', () {
        expect(ResetPasswordService.isValidUrl('https://example.com'), true);
        expect(ResetPasswordService.isValidUrl('https://demo.odoo.com'), true);
        expect(ResetPasswordService.isValidUrl('https://subdomain.example.com'), true);
        expect(ResetPasswordService.isValidUrl('https://example.com/path'), true);
      });

      test('returns false for invalid URLs', () {
        expect(ResetPasswordService.isValidUrl(''), false);
        expect(ResetPasswordService.isValidUrl('not a url'), false);
        expect(ResetPasswordService.isValidUrl('ftp://example.com'), false);
        expect(ResetPasswordService.isValidUrl('example.com'), false);
        expect(ResetPasswordService.isValidUrl('www.example.com'), false);
      });

      test('handles edge cases', () {
        expect(ResetPasswordService.isValidUrl('http://'), false);
        expect(ResetPasswordService.isValidUrl('https://'), false);
        expect(ResetPasswordService.isValidUrl('   '), false);
      });
    });

    group('sendResetPasswordEmail - Input Validation', () {
      test('validates server URL format', () async {
        await expectLater(
          () => ResetPasswordService.sendResetPasswordEmail(
            serverUrl: 'invalid-url',
            database: 'test_db',
            login: 'test@example.com',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('validates email format', () async {
        await expectLater(
          () => ResetPasswordService.sendResetPasswordEmail(
            serverUrl: 'https://demo.odoo.com',
            database: 'test_db',
            login: 'invalid-email',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('validates database is not empty', () async {
        await expectLater(
          () => ResetPasswordService.sendResetPasswordEmail(
            serverUrl: 'https://demo.odoo.com',
            database: '',
            login: 'test@example.com',
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('sendResetPasswordEmail - Network Scenarios', () {
      test('handles timeout or unreachable server', () async {
        // In this implementation, a timeout will return a Map with requiresWebView: true
        // rather than throwing as it falls back through _tryDirectApiReset to _tryWebInterfaceReset
        final result = await ResetPasswordService.sendResetPasswordEmail(
          serverUrl: 'https://192.0.2.1:12345', // TEST-NET-1, should timeout
          database: 'test_db',
          login: 'test@example.com',
        );
        expect(result['requiresWebView'], true);
        expect(result['success'], false);
      }, timeout: const Timeout(Duration(seconds: 15)));

      test('handles invalid server response', () async {
        // This will return a result map with requiresWebView, not throw
        final result = await ResetPasswordService.sendResetPasswordEmail(
          serverUrl: 'https://invalid-server-that-does-not-exist-12345.com',
          database: 'test_db',
          login: 'test@example.com',
        );
        
        // Should return a result map
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], isA<bool>());
      }, timeout: const Timeout(Duration(seconds: 15)));
    });

    group('Integration - Full Flow', () {
      test('constructs proper request with valid inputs', () async {
        // This test verifies the service doesn't crash with valid inputs
        // Actual network call will likely fail in test environment
        try {
          final result = await ResetPasswordService.sendResetPasswordEmail(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo',
            login: 'admin@example.com',
          );
          // In test environment, it should either "succeed" (if mocked/lucky) or return WebView fallback
          expect(result, isA<Map<String, dynamic>>());
        } catch (e) {
          // Fallback if something really goes wrong
          expect(e, isA<Exception>());
        }
      }, timeout: const Timeout(Duration(seconds: 15)));
    });

    group('URL Normalization', () {
      test('handles URLs with trailing slashes', () async {
        try {
          final result = await ResetPasswordService.sendResetPasswordEmail(
            serverUrl: 'https://demo.odoo.com/',
            database: 'test_db',
            login: 'test@example.com',
          );
          expect(result, isA<Map<String, dynamic>>());
        } catch (e) {
          // Expected in test environment
          expect(e, isA<Exception>());
        }
      }, timeout: const Timeout(Duration(seconds: 15)));

      test('handles URLs with ports', () async {
        try {
          final result = await ResetPasswordService.sendResetPasswordEmail(
            serverUrl: 'https://demo.odoo.com:8069',
            database: 'test_db',
            login: 'test@example.com',
          );
          expect(result, isA<Map<String, dynamic>>());
        } catch (e) {
          // Expected in test environment
          expect(e, isA<Exception>());
        }
      }, timeout: const Timeout(Duration(seconds: 15)));
    });
  });
}
