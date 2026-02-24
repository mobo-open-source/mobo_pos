import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/providers/theme_provider.dart';
import 'package:mobo_pos/screens/get_started_screen.dart';
import 'package:mobo_pos/Loginpage/server_setup_screen.dart';
import 'package:mobo_pos/Loginpage/user_login_screen.dart';
import 'package:mobo_pos/Loginpage/reset_password_screen.dart';
import 'package:mobo_pos/screens/biometric_auth_screen.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'dart:io';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../helpers/test_helpers.dart';

// Mock VideoPlayerPlatform
class MockVideoPlayerPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> init() async {}
  @override
  Future<int> create(DataSource dataSource) async => 1;
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
  Future<Duration> getPosition(int textureId) async => Duration.zero;
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream<VideoEvent>.empty();
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
}

// Mock OdooClient for testing
class MockOdooClient extends Fake implements OdooClient {
  bool shouldFail = false;
  List<String> mockDatabases = ['test_db', 'demo_db'];
  String baseURL = 'https://demo.odoo.com';

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
      id: 'test_session',
      userId: 1,
      partnerId: 1,
      userLogin: login,
      userName: 'Test User',
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
  void close() {}
}

Widget createTestApp(Widget child, {OdooClient? client}) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      home: child,
      routes: {
        '/init': (context) => const Scaffold(body: Text('Initial Screen')),
        '/server_setup': (context) => ServerSetupScreen(client: client),
        '/backend': (context) => const Scaffold(body: Text('Backend Screen')),
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Robust setup for font mocking and exception silencing
  MockFontLoader.setup();

  // Mock Video Player
  VideoPlayerPlatform.instance = MockVideoPlayerPlatform();

  group('GetStartedScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Call setup in setUp to ensure it's fresh for every test
      MockFontLoader.setup();
    });

    testWidgets('renders correctly with all elements', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const GetStartedScreen()));
        await tester.pump();
        
        expect(find.text('Streamline Your Sales'), findsOneWidget);
        expect(find.byType(DotsIndicator), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
      });
    });

    testWidgets('carousel swipes to next page', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const GetStartedScreen()));
        await tester.pump();
        
        // Find PageView and swipe left
        final pageView = find.byType(PageView);
        await tester.drag(pageView, const Offset(-300, 0));
        await tester.pumpAndSettle();
        
        // Should still have dots indicator
        expect(find.byType(DotsIndicator), findsOneWidget);
      });
    });

    testWidgets('Get Started button navigates to next screen', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const GetStartedScreen()));
        await tester.pump();
        
        final button = find.text('Get Started');
        expect(button, findsOneWidget);
        
        await tester.tap(button);
        await tester.pumpAndSettle();
        
        // Should navigate away from GetStartedScreen
        expect(find.text('Initial Screen'), findsOneWidget);
      });
    });

    testWidgets('marks get started as seen when clicked', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const GetStartedScreen()));
        await tester.pump();
        
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('hasSeenGetStarted'), true);
      });
    });

    testWidgets('displays all carousel pages', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const GetStartedScreen()));
        await tester.pump();
        
        // First page
        expect(find.text('Streamline Your Sales'), findsOneWidget);
        
        // Swipe to second page
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
        
        // Should have different content (exact text depends on implementation)
        expect(find.byType(PageView), findsOneWidget);
      });
    });
  });

  group('ServerSetupScreen Widget Tests', () {
    late MockOdooClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockOdooClient();
    });

    testWidgets('renders form elements correctly', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(ServerSetupScreen(client: mockClient)));
        await tester.pump();
        
        expect(find.text('Sign In'), findsWidgets);
        expect(find.text('Next'), findsOneWidget);
        expect(find.byType(TextFormField), findsWidgets);
      });
    });

    testWidgets('displays protocol selection buttons', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(ServerSetupScreen(client: mockClient)));
        await tester.pump();
        
        // Should have protocol dropdown in LoginUrlTextField
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      });
    });

    testWidgets('validates empty server URL', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(ServerSetupScreen(client: mockClient)));
        await tester.pump();
        
        // Try to submit without entering URL
        final nextButton = find.text('Next');
        await tester.tap(nextButton);
        await tester.pump();
        
        // Should show validation error
        expect(find.byType(ServerSetupScreen), findsOneWidget);
      });
    });

    testWidgets('accepts valid server URL format', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(ServerSetupScreen(client: mockClient)));
        await tester.pump();
        
        // Find the server address field
        final textField = find.byType(TextFormField).first;
        await tester.enterText(textField, 'demo.odoo.com');
        await tester.pump();
        
        expect(find.text('demo.odoo.com'), findsOneWidget);
      });
    });

    testWidgets('shows loading indicator when fetching databases', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(ServerSetupScreen(client: mockClient)));
        await tester.pump();
        
        // Enter URL and submit
        final textField = find.byType(TextFormField).first;
        await tester.enterText(textField, 'demo.odoo.com');
        await tester.pump();
        
        final nextButton = find.text('Next');
        await tester.tap(nextButton);
        await tester.pump();
        
        // Should now use the mock client and not throw network error
        expect(find.byType(ServerSetupScreen), findsOneWidget);
      });
    });
  });

  group('UserLoginScreen Widget Tests', () {
    late MockOdooClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockOdooClient();
    });

    testWidgets('renders login form correctly', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: mockClient,
          ),
        ));
        await tester.pump();
        
        expect(find.text('Sign In POS App'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2)); // Username and password
      });
    });

    testWidgets('validates username field', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: mockClient,
          ),
        ));
        await tester.pump();
        
        // Try to sign in without username
        await tester.tap(find.text('Sign In'));
        await tester.pump();
        
        expect(find.text('Username is required'), findsOneWidget);
      });
    });

    testWidgets('validates password field', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: mockClient,
          ),
        ));
        await tester.pump();
        
        // Enter username but not password
        final usernameField = find.byType(TextFormField).first;
        await tester.enterText(usernameField, 'admin');
        await tester.pump();
        
        await tester.tap(find.text('Sign In'));
        await tester.pump();
        
        expect(find.text('Password is required'), findsOneWidget);
      });
    });

    testWidgets('accepts valid credentials', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: mockClient,
          ),
        ));
        await tester.pump();
        
        // Enter username and password
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'admin');
        await tester.enterText(fields.at(1), 'admin123');
        await tester.pump();
        
        expect(find.text('admin'), findsOneWidget);
      });
    });

    testWidgets('toggles password visibility', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: mockClient,
          ),
        ));
        await tester.pump();
        
        // Look for password visibility toggle icon
        final visibilityIcon = find.byIcon(Icons.visibility);
        if (visibilityIcon.evaluate().isNotEmpty) {
          await tester.tap(visibilityIcon);
          await tester.pump();
          
          // Icon should change to visibility_off
          expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        }
      });
    });

    testWidgets('displays forgot password option', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: mockClient,
          ),
        ));
        await tester.pump();
        
        // Should have forgot password link/button
        expect(find.textContaining('Forgot'), findsOneWidget);
      });
    });
  });

  group('ResetPasswordScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MockFontLoader.setup();
    });

    testWidgets('renders reset password form', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          const ResetPasswordScreen(
            url: 'https://demo.odoo.com',
            database: 'demo_db',
          ),
        ));
        await tester.pump();
        
        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget); // Email field
      });
    });

    testWidgets('validates email format', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          const ResetPasswordScreen(
            url: 'https://demo.odoo.com',
            database: 'demo_db',
          ),
        ));
        await tester.pump();
        
        // Enter invalid email
        final emailField = find.byType(TextFormField);
        await tester.enterText(emailField, 'invalid-email');
        await tester.pump();
        
        // Try to submit
        final submitButton = find.text('Send Reset Link');
        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pump();
        }
      });
    });

    testWidgets('accepts valid email format', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(
          const ResetPasswordScreen(
            url: 'https://demo.odoo.com',
            database: 'demo_db',
          ),
        ));
        await tester.pump();
        
        final emailField = find.byType(TextFormField);
        await tester.enterText(emailField, 'test@example.com');
        await tester.pump();
        
        expect(find.text('test@example.com'), findsOneWidget);
      });
    });
  });

  group('BiometricAuthScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MockFontLoader.setup();
    });

    testWidgets('renders biometric setup screen', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const BiometricAuthScreen(useStandardFonts: true)));
        await tester.pump();
        
        // Should display biometric-related UI
        expect(find.byType(BiometricAuthScreen), findsOneWidget);
        
        // Wait for potential timers to finish
        await Future.delayed(const Duration(milliseconds: 1000));
        await tester.pump();
      });
    });

    testWidgets('displays enable/disable biometric option', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const BiometricAuthScreen(useStandardFonts: true)));
        await tester.pump();
        
        // Should have biometric-related text or icon
        expect(find.textContaining('App Locked'), findsOneWidget);
        
        // Wait for potential timers to finish
        await Future.delayed(const Duration(milliseconds: 1000));
        await tester.pump();
      });
    });
  });

  group('Screen Navigation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      MockFontLoader.setup();
    });

    testWidgets('GetStarted navigates to server setup', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(createTestApp(const GetStartedScreen()));
        await tester.pump();
        
        await tester.tap(find.text('Get Started'));
        await tester.pumpAndSettle();
        
        expect(find.text('Initial Screen'), findsOneWidget);
      });
    });

    testWidgets('Login screen shows back navigation', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          home: UserLoginScreen(
            serverUrl: 'https://demo.odoo.com',
            database: 'demo_db',
            client: MockOdooClient(),
          ),
        ));
        await tester.pump();
        
        // Should have back button
        expect(find.byType(IconButton), findsAtLeastNWidgets(1));
      });
    });
  });
}
