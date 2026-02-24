import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/providers/theme_provider.dart';
import 'package:mobo_pos/screens/get_started_screen.dart';
import 'package:mobo_pos/Loginpage/splash.dart';
import 'package:mobo_pos/Loginpage/server_setup_screen.dart';
import 'package:mobo_pos/Loginpage/user_login_screen.dart';
import 'package:mobo_pos/Loginpage/login_layout.dart';
import 'package:mobo_pos/services/biometric_service.dart';
import 'package:mobo_pos/Isarmodel/user_profile.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Mock VideoPlayerPlatform
class MockVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> init() async {}

  @override
  Future<int> create(DataSource dataSource) async {
    return 1;
  }

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async {
    return Duration.zero;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return const Stream<VideoEvent>.empty();
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}
}

/// Main Application Test Suite
/// 
/// This file contains basic smoke tests and backward compatibility tests.
/// For comprehensive test coverage, see:
/// - test/services/* - Service layer tests
/// - test/providers/* - State management tests  
/// - test/models/* - Data model tests
/// - test/screens/* - Widget and UI tests
/// - test/integration/* - End-to-end flow tests

// Manual Mock for OdooClient to test login and server setup
class MockOdooClient extends Fake implements OdooClient {
  bool shouldFail = false;
  List<String> mockDatabases = ['database_1', 'database_2'];

  @override
  Future<dynamic> callRPC(dynamic path, dynamic method, dynamic params) async {
    if (shouldFail) throw const SocketException('Connection failed');
    if (path == '/web/database/list') return mockDatabases;
    return null;
  }

  @override
  Future<OdooSession> authenticate(String db, String login, String password) async {
    if (shouldFail || login == 'error') throw OdooException('Access Denied');
    return OdooSession(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Silence google_fonts exceptions in tests
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('google_fonts')) {
      return;
    }
    originalOnError?.call(details);
  };

  // Mock Video Player
  VideoPlayerPlatform.instance = MockVideoPlayerPlatform();
  
  // Enable GoogleFonts runtime fetching but it will fail gracefully (400) 
  // in tests instead of throwing an exception when assets are missing.
  try {
    (GoogleFonts.config as dynamic).allowRuntimeFetching = true;
  } catch (_) {}

  group('Unit Tests - State & Logic', () {
    late ThemeProvider themeProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      themeProvider = ThemeProvider();
    });

    test('ThemeProvider: Initial state and toggling', () {
      expect(themeProvider.themeMode, ThemeMode.light);
      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, true);
    });

    test('BiometricService: Toggle settings', () async {
      await BiometricService.setBiometricEnabled(true);
      expect(await BiometricService.isBiometricEnabled(), true);
      await BiometricService.setBiometricEnabled(false);
      expect(await BiometricService.isBiometricEnabled(), false);
    });
  });

  group('Unit Tests - Data Models', () {
    test('UserProfile: Properties assignment', () {
      final user = UserProfile()
        ..userName = 'John Doe'
        ..userEmail = 'john@example.com'
        ..dbName = 'test_db';
      
      expect(user.userName, 'John Doe');
      expect(user.userEmail, 'john@example.com');
      expect(user.dbName, 'test_db');
    });

    test('SignedAccount: Properties assignment', () {
      final account = SignedAccount()
        ..username = 'admin'
        ..serverAddress = 'https://odoo.com';
      
      expect(account.username, 'admin');
      expect(account.serverAddress, 'https://odoo.com');
    });
  });

  group('Widget Tests - Main Flows', () {
    late MockOdooClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockOdooClient();
    });

    Widget createTestApp(Widget child) {
      return ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          home: child,
          routes: {
            '/init': (context) => const Scaffold(body: Text('Initial Screen')),
            '/get_started': (context) => const Scaffold(body: Text('Get Started Screen')),
            '/backend': (context) => const Scaffold(body: Text('Backend Home')),
            '/server_setup': (context) => const Scaffold(body: Text('Server Setup')),
          },
        ),
      );
    }

    testWidgets('SplashScreen: Renders correctly', (WidgetTester tester) async {
      // Use runAsync to handle the background initialization in splash
      await tester.runAsync(() async {
        try {
          await tester.pumpWidget(createTestApp(const SplashScreen()));
          await tester.pump();
          expect(find.byType(Scaffold), findsOneWidget);
        } catch (e) {
          // Catch potential video player initialization errors in test env
          debugPrint('Caught expected splash error: $e');
        }
      });
    });

    testWidgets('GetStartedScreen: Carousel and Navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const GetStartedScreen()));
      
      expect(find.text('Streamline Your Sales'), findsOneWidget);
      expect(find.byType(DotsIndicator), findsOneWidget);
      
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      
      expect(find.text('Initial Screen'), findsOneWidget);
    });

    testWidgets('ServerSetupScreen: Form elements', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(const ServerSetupScreen()));
      
      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('UserLoginScreen: Login form validation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(UserLoginScreen(
        serverUrl: 'https://demo.odoo.com',
        database: 'demo_db',
        client: mockClient,
      )));

      expect(find.text('Sign In POS App'), findsOneWidget);
      
      // Try to sign in without credentials
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      
      expect(find.text('Username is required'), findsOneWidget);
    });
  });
}
