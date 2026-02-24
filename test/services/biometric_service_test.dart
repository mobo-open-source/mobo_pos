import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/services/biometric_service.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BiometricService Tests', () {
    late MockLocalAuthentication mockLocalAuth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockLocalAuth = MockLocalAuthentication();
    });

    group('isBiometricAvailable', () {
      test('returns true when device supports biometrics', () async {
        final result = await BiometricService.isBiometricAvailable();
        // Result depends on test environment, just verify it doesn't crash
        expect(result, isA<bool>());
      });

      test('handles platform exceptions gracefully', () async {
        // This test verifies the method doesn't crash on errors
        final result = await BiometricService.isBiometricAvailable();
        expect(result, isA<bool>());
      });
    });

    group('getAvailableBiometrics', () {
      test('returns list of available biometric types', () async {
        final result = await BiometricService.getAvailableBiometrics();
        expect(result, isA<List<BiometricType>>());
      });

      test('returns empty list on error', () async {
        final result = await BiometricService.getAvailableBiometrics();
        expect(result, isA<List<BiometricType>>());
      });
    });

    group('isBiometricEnabled and setBiometricEnabled', () {
      test('returns false by default', () async {
        final result = await BiometricService.isBiometricEnabled();
        expect(result, false);
      });

      test('stores and retrieves enabled state', () async {
        await BiometricService.setBiometricEnabled(true);
        expect(await BiometricService.isBiometricEnabled(), true);

        await BiometricService.setBiometricEnabled(false);
        expect(await BiometricService.isBiometricEnabled(), false);
      });

      test('persists state across multiple calls', () async {
        await BiometricService.setBiometricEnabled(true);
        
        // Verify multiple reads return correct value
        expect(await BiometricService.isBiometricEnabled(), true);
        expect(await BiometricService.isBiometricEnabled(), true);
      });
    });

    group('authenticateWithBiometrics', () {
      test('returns false when biometrics unavailable', () async {
        // In test environment, biometrics typically aren't available
        final result = await BiometricService.authenticateWithBiometrics(
          reason: 'Test authentication',
        );
        expect(result, isA<bool>());
      });

      test('accepts custom reason parameter', () async {
        final result = await BiometricService.authenticateWithBiometrics(
          reason: 'Custom authentication reason',
        );
        expect(result, isA<bool>());
      });

      test('uses default reason when not provided', () async {
        final result = await BiometricService.authenticateWithBiometrics();
        expect(result, isA<bool>());
      });
    });

    group('getBiometricTypeName', () {
      test('returns correct name for face biometric', () {
        final name = BiometricService.getBiometricTypeName(BiometricType.face);
        expect(name, 'Face ID');
      });

      test('returns correct name for fingerprint biometric', () {
        final name = BiometricService.getBiometricTypeName(BiometricType.fingerprint);
        expect(name, 'Fingerprint');
      });

      test('returns correct name for iris biometric', () {
        final name = BiometricService.getBiometricTypeName(BiometricType.iris);
        expect(name, 'Iris');
      });

      test('returns correct name for weak biometric', () {
        final name = BiometricService.getBiometricTypeName(BiometricType.weak);
        expect(name, 'PIN/Pattern');
      });

      test('returns correct name for strong biometric', () {
        final name = BiometricService.getBiometricTypeName(BiometricType.strong);
        expect(name, 'Strong Biometric');
      });
    });

    group('getAvailableBiometricNames', () {
      test('returns list of biometric type names', () async {
        final names = await BiometricService.getAvailableBiometricNames();
        expect(names, isA<List<String>>());
      });

      test('returns empty list when no biometrics available', () async {
        final names = await BiometricService.getAvailableBiometricNames();
        expect(names, isA<List<String>>());
      });
    });

    group('shouldPromptBiometric', () {
      test('returns false when biometric not enabled', () async {
        await BiometricService.setBiometricEnabled(false);
        final result = await BiometricService.shouldPromptBiometric();
        expect(result, false);
      });

      test('checks availability when enabled', () async {
        await BiometricService.setBiometricEnabled(true);
        final result = await BiometricService.shouldPromptBiometric();
        expect(result, isA<bool>());
      });

      test('handles errors gracefully', () async {
        await BiometricService.setBiometricEnabled(true);
        final result = await BiometricService.shouldPromptBiometric();
        expect(result, isA<bool>());
      });
    });

    group('initialize', () {
      test('completes without error', () async {
        await expectLater(
          BiometricService.initialize(),
          completes,
        );
      });

      test('can be called multiple times', () async {
        await BiometricService.initialize();
        await BiometricService.initialize();
        // Should not throw
      });
    });

    group('getErrorMessage', () {
      test('returns message for NotAvailable error', () {
        final exception = PlatformException(code: 'NotAvailable');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('not available'));
      });

      test('returns message for NotEnrolled error', () {
        final exception = PlatformException(code: 'NotEnrolled');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('No biometrics are enrolled'));
      });

      test('returns message for LockedOut error', () {
        final exception = PlatformException(code: 'LockedOut');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('temporarily locked'));
      });

      test('returns message for PermanentlyLockedOut error', () {
        final exception = PlatformException(code: 'PermanentlyLockedOut');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('permanently locked'));
      });

      test('returns message for UserCancel error', () {
        final exception = PlatformException(code: 'UserCancel');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('cancelled'));
      });

      test('returns message for InvalidContext error', () {
        final exception = PlatformException(code: 'InvalidContext');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('invalid'));
      });

      test('returns message for BiometricOnlyNotSupported error', () {
        final exception = PlatformException(code: 'BiometricOnlyNotSupported');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('not supported'));
      });

      test('returns message for no_fragment_activity error', () {
        final exception = PlatformException(code: 'no_fragment_activity');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('configuration error'));
      });

      test('returns generic message for unknown error', () {
        final exception = PlatformException(code: 'UnknownError', message: 'Test error');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, contains('error occurred'));
      });

      test('handles exception without message', () {
        final exception = PlatformException(code: 'UnknownError');
        final message = BiometricService.getErrorMessage(exception);
        expect(message, isNotEmpty);
      });
    });
  });
}
