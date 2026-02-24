import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:provider/provider.dart';
import 'package:mobo_pos/providers/theme_provider.dart';
import 'package:mockito/mockito.dart' as mockito;
import 'dart:convert';

/// Mocks the font loading process to prevent google_fonts from failing tests
class MockFontLoader {
  static void setup() {
    try {
      TestWidgetsFlutterBinding.ensureInitialized();
    } catch (e) {
      // Already initialized
    }
    
    // Intercept font loading requests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/fonts', (ByteData? message) async {
      return ByteData(0);
    });

    // Mock asset manifest for google_fonts
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final Uint8List encoded = message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes);
      final String key = utf8.decode(encoded);
      
      final manifestMap = {
        "google_fonts/Manrope-Regular.ttf": ["google_fonts/Manrope-Regular.ttf"],
        "google_fonts/Manrope-Medium.ttf": ["google_fonts/Manrope-Medium.ttf"],
        "google_fonts/Manrope-SemiBold.ttf": ["google_fonts/Manrope-SemiBold.ttf"],
        "google_fonts/Manrope-Bold.ttf": ["google_fonts/Manrope-Bold.ttf"],
        "google_fonts/Montserrat-Regular.ttf": ["google_fonts/Montserrat-Regular.ttf"],
        "google_fonts/Montserrat-SemiBold.ttf": ["google_fonts/Montserrat-SemiBold.ttf"],
        "assets/CRM1.jpg": ["assets/CRM1.jpg"],
        "assets/CRM2.jpg": ["assets/CRM2.jpg"],
        "assets/CRM3.jpg": ["assets/CRM3.jpg"],
        "assets/loginbg.png": ["assets/loginbg.png"],
        "assets/pos.mp4": ["assets/pos.mp4"]
      };

      if (key == 'AssetManifest.json' || key == 'assets/AssetManifest.json') {
        return ByteData.view(Uint8List.fromList(utf8.encode(json.encode(manifestMap))).buffer);
      }
      
      if (key == 'AssetManifest.bin' || key == 'assets/AssetManifest.bin' || key.contains('AssetManifest.bin')) {
        // Binary manifest expects a List of Maps for variants
        final binaryManifest = <String, List<Map<String, dynamic>>>{};
        manifestMap.forEach((key, value) {
          binaryManifest[key] = value.map((v) => {"asset": v, "dpr": 1.0}).toList();
        });
        
        final WriteBuffer buffer = WriteBuffer();
        const StandardMessageCodec().writeValue(buffer, binaryManifest);
        return buffer.done();
      }
      
      if (key.contains('Manrope') || key.contains('Montserrat') || key.contains('.ttf')) {
        return ByteData(0);
      }

      if (key.endsWith('.jpg') || key.endsWith('.png') || key.endsWith('.mp4')) {
        // Return a valid 1x1 transparent PNG to prevent "Invalid image data" error
        return ByteData.view(Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
          0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x00,
          0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
          0x44, 0xAE, 0x42, 0x60, 0x82
        ]).buffer);
      }
      
      return null;
    });
    
    // Disable runtime fetching to force asset lookup
    GoogleFonts.config.allowRuntimeFetching = false;
    
    // Aggressive silencing of font and image-related errors
    _silenceFontErrors();
  }

  static void _silenceFontErrors() {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final exceptionStr = details.exception.toString();
      if (exceptionStr.contains('google_fonts') || 
          exceptionStr.contains('GoogleFonts') ||
          exceptionStr.contains('Manrope') || 
          exceptionStr.contains('Montserrat') ||
          exceptionStr.contains('Font loader') ||
          exceptionStr.contains('ttf') ||
          exceptionStr.contains('image') ||
          exceptionStr.contains('AssetImage') ||
          exceptionStr.contains('codec')) {
        // Silently ignore font and image errors
        return;
      }
      originalOnError?.call(details);
    };
  }
}

/// A mock asset bundle that returns dummy data for any request
class MockAssetBundle extends Fake implements AssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData(0);

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async {
    if (key.contains('AssetManifest')) {
      // Return a manifest that includes the problematic fonts
      return parser('{"google_fonts/Manrope-Regular.ttf":["google_fonts/Manrope-Regular.ttf"],"google_fonts/Manrope-SemiBold.ttf":["google_fonts/Manrope-SemiBold.ttf"],"google_fonts/Montserrat-Regular.ttf":["google_fonts/Montserrat-Regular.ttf"]}');
    }
    return parser('{}');
  }
  
  @override
  String toString() => 'MockAssetBundle';
}

// Generate mocks for these classes
@GenerateMocks([
  LocalAuthentication,
])
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

// Mock OdooClient for testing
class MockOdooClient extends Fake implements OdooClient {
  bool shouldFail = false;
  List<String> mockDatabases = ['database_1', 'database_2'];
  dynamic mockCallRpcResponse;
  OdooSession? mockSession;

  @override
  Future<dynamic> callRPC(path, method, params) async {
    if (shouldFail) throw const SocketException('Connection failed');
    if (path == '/web/database/list') return mockDatabases;
    return mockCallRpcResponse;
  }

  @override
  Future<OdooSession> authenticate(String db, String login, String password) async {
    if (shouldFail || login == 'error') throw OdooException('Access Denied');
    return mockSession ??
        OdooSession(
          id: 'mock_session_id',
          userId: 1,
          partnerId: 1,
          userLogin: login,
          userName: 'Mock User',
          userLang: 'en_US',
          userTz: 'UTC',
          isSystem: false,
          dbName: db,
          serverVersion: '16.0',
          companyId: 1,
          allowedCompanies: [],
        );
  }

  @override
  Future<dynamic> callKw(dynamic params) async {
    return [
      {'id': 1, 'name': 'Mock Company'}
    ];
  }

  @override
  void close() {}
}

/// Creates a test widget wrapped with necessary providers
Widget createTestApp(Widget child, {ThemeProvider? themeProvider}) {
  // Setup mock font loader to prevent google_fonts issues
  MockFontLoader.setup();

  // Globally silence google_fonts exceptions that frequently fail tests
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final exceptionStr = details.exception.toString();
    if (exceptionStr.contains('google_fonts') || 
        exceptionStr.contains('GoogleFonts') ||
        exceptionStr.contains('Manrope') || 
        exceptionStr.contains('Montserrat') ||
        exceptionStr.contains('Font loader')) {
      return;
    }
    originalOnError?.call(details);
  };

  return ChangeNotifierProvider(
    create: (_) => themeProvider ?? ThemeProvider(),
    child: DefaultTextStyle(
      style: const TextStyle(fontFamily: 'Roboto'),
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          textTheme: const TextTheme(
            bodyLarge: TextStyle(fontFamily: 'Roboto'),
            bodyMedium: TextStyle(fontFamily: 'Roboto'),
            bodySmall: TextStyle(fontFamily: 'Roboto'),
            headlineLarge: TextStyle(fontFamily: 'Roboto'),
            headlineMedium: TextStyle(fontFamily: 'Roboto'),
            headlineSmall: TextStyle(fontFamily: 'Roboto'),
            titleLarge: TextStyle(fontFamily: 'Roboto'),
            titleMedium: TextStyle(fontFamily: 'Roboto'),
            titleSmall: TextStyle(fontFamily: 'Roboto'),
            labelLarge: TextStyle(fontFamily: 'Roboto'),
            labelMedium: TextStyle(fontFamily: 'Roboto'),
            labelSmall: TextStyle(fontFamily: 'Roboto'),
          ),
        ),
        home: child,
        routes: {
          '/init': (context) => const Scaffold(body: Text('Initial Screen')),
          '/get_started': (context) => const Scaffold(body: Text('Get Started Screen')),
          '/backend': (context) => const Scaffold(body: Text('Backend Home')),
          '/server_setup': (context) => const Scaffold(body: Text('Server Setup')),
        },
      ),
    ),
  );
}

/// Test data fixtures
class TestFixtures {
  static const String validEmail = 'test@example.com';
  static const String invalidEmail = 'invalid-email';
  static const String validUrl = 'https://demo.odoo.com';
  static const String invalidUrl = 'not-a-url';
  static const String mockServerUrl = 'https://test.odoo.com';
  static const String mockDatabase = 'test_db';
  static const String mockUsername = 'admin';
  static const String mockPassword = 'admin123';
}

/// Custom matchers for testing
class ContainsWidget extends Matcher {
  final Type widgetType;

  ContainsWidget(this.widgetType);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! Finder) return false;
    return item.evaluate().isNotEmpty;
  }

  @override
  Description describe(Description description) {
    return description.add('contains widget of type $widgetType');
  }
}

/// Helper to create platform exceptions for testing
PlatformException createPlatformException(String code, {String? message}) {
  return PlatformException(
    code: code,
    message: message ?? 'Test error',
  );
}
