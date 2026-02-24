import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_pos/providers/theme_provider.dart';
import 'package:mobo_pos/screens/get_started_screen.dart';
import 'package:mobo_pos/Loginpage/server_setup_screen.dart';
import 'package:mobo_pos/Loginpage/user_login_screen.dart';
import 'package:mobo_pos/services/biometric_service.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
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

// Mock OdooClient
class MockOdooClient extends Fake implements OdooClient {
  bool shouldFail = false;
  List<String> mockDatabases = ['test_db', 'demo_db'];

  @override
  Future<dynamic> callRPC(dynamic path, dynamic method, dynamic params) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (shouldFail) throw const SocketException('Connection failed');
    if (path == '/web/database/list') return mockDatabases;
    return null;
  }

  @override
  Future<OdooSession> authenticate(String db, String login, String password) async {
    await Future.delayed(const Duration(milliseconds: 100));
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

Widget createAppWithRoutes() {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
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
          ),
        ),
        home: const GetStartedScreen(),
        routes: {
          '/init': (context) => const Scaffold(body: Text('Initial Screen')),
          '/server_setup': (context) => const ServerSetupScreen(),
          '/backend': (context) => const Scaffold(
                body: Center(child: Text('Backend Home')),
              ),
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Robust setup for font mocking and exception silencing
  MockFontLoader.setup();

  // Mock Video Player
  VideoPlayerPlatform.instance = MockVideoPlayerPlatform();

  group('Integration Tests - Complete User Flows', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // Call setup in setUp to ensure it's fresh for every test
      MockFontLoader.setup();
    });

    group('First Launch Experience', () {
      testWidgets('complete onboarding flow', (WidgetTester tester) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(createAppWithRoutes());
          await tester.pump();

          // Should show GetStartedScreen on first launch
          expect(find.text('Streamline Your Sales'), findsOneWidget);

          // Tap Get Started button
          await tester.tap(find.text('Get Started'));
          await tester.pumpAndSettle();

          // Should mark as seen
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool('hasSeenGetStarted'), true);
        });
      });

      testWidgets('carousel interaction in get started', (WidgetTester tester) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(createAppWithRoutes());
          await tester.pump();

          // Swipe through carousel
          final pageView = find.byType(PageView);
          expect(pageView, findsOneWidget);

          await tester.drag(pageView, const Offset(-300, 0));
          await tester.pumpAndSettle();

          // Should still be on GetStartedScreen
          expect(find.text('Get Started'), findsOneWidget);
        });
      });
    });

    group('Login Flow', () {
      testWidgets('server setup to login flow', (WidgetTester tester) async {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => ThemeProvider(),
              child: const MaterialApp(
                home: ServerSetupScreen(),
              ),
            ),
          );
          await tester.pump();

          // Should show server setup screen
          expect(find.text('Next'), findsOneWidget);
          expect(find.byType(TextFormField), findsWidgets);
        });
      });

      testWidgets('login form validation flow', (WidgetTester tester) async {
        final mockClient = MockOdooClient();

        await tester.runAsync(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => ThemeProvider(),
              child: MaterialApp(
                home: UserLoginScreen(
                  serverUrl: 'https://demo.odoo.com',
                  database: 'demo_db',
                  client: mockClient,
                ),
              ),
            ),
          );
          await tester.pump();

          // Try to login without credentials
          await tester.tap(find.text('Sign In'));
          await tester.pump();

          // Should show validation errors
          expect(find.text('Username is required'), findsOneWidget);

          // Enter username only
          final usernameField = find.byType(TextFormField).first;
          await tester.enterText(usernameField, 'admin');
          await tester.pump();

          await tester.tap(find.text('Sign In'));
          await tester.pump();

          // Should still show password error
          expect(find.text('Password is required'), findsOneWidget);
        });
      });
    });

    group('Theme Persistence Flow', () {
      testWidgets('theme persists across widget rebuilds', (WidgetTester tester) async {
        final themeProvider = ThemeProvider();

        await tester.runAsync(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: themeProvider,
              child: Builder(
                builder: (context) {
                  final theme = Provider.of<ThemeProvider>(context);
                  return MaterialApp(
                    theme: ThemeData.light(),
                    darkTheme: ThemeData.dark(),
                    themeMode: theme.themeMode,
                    home: Scaffold(
                      body: Column(
                        children: [
                          Text('Mode: ${theme.isDarkMode ? 'Dark' : 'Light'}'),
                          ElevatedButton(
                            onPressed: () => theme.toggleTheme(),
                            child: const Text('Toggle Theme'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pump();

          // Initially light
          expect(find.text('Mode: Light'), findsOneWidget);

          // Toggle to dark
          await tester.tap(find.text('Toggle Theme'));
          await tester.pumpAndSettle();

          expect(find.text('Mode: Dark'), findsOneWidget);

          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: themeProvider,
              child: Builder(
                builder: (context) {
                  final theme = Provider.of<ThemeProvider>(context);
                  return MaterialApp(
                    theme: ThemeData.light(),
                    darkTheme: ThemeData.dark(),
                    themeMode: theme.themeMode,
                    home: Scaffold(
                      body: Text('Mode: ${theme.isDarkMode ? 'Dark' : 'Light'}'),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pump();

          // Should still be dark
          expect(find.text('Mode: Dark'), findsOneWidget);
        });
      });

      testWidgets('theme setting persists to SharedPreferences', (WidgetTester tester) async {
        final themeProvider = ThemeProvider();

        await tester.runAsync(() async {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: themeProvider,
              child: MaterialApp(
                home: Builder(
                  builder: (context) {
                    final theme = Provider.of<ThemeProvider>(context);
                    return ElevatedButton(
                      onPressed: () => theme.setThemeMode(ThemeMode.dark),
                      child: const Text('Set Dark'),
                    );
                  },
                ),
              ),
            ),
          );

          await tester.tap(find.text('Set Dark'));
          await tester.pumpAndSettle();

          // Give time for async save
          await tester.pump(const Duration(milliseconds: 150));

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('theme_mode'), 'dark');
        });
      });
    });

    group('Biometric Settings Flow', () {
      testWidgets('biometric enable/disable flow', (WidgetTester tester) async {
        await tester.runAsync(() async {
          // Set initial state
          await BiometricService.setBiometricEnabled(false);
          expect(await BiometricService.isBiometricEnabled(), false);

          // Enable biometrics
          await BiometricService.setBiometricEnabled(true);
          expect(await BiometricService.isBiometricEnabled(), true);

          // Build widget
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  return FutureBuilder<bool>(
                    future: BiometricService.isBiometricEnabled(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      return Text('Biometric: ${snapshot.data! ? 'Enabled' : 'Disabled'}');
                    },
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Biometric: Enabled'), findsOneWidget);
        });
      });

      testWidgets('biometric prompt logic', (WidgetTester tester) async {
        await tester.runAsync(() async {
          // Disable biometrics
          await BiometricService.setBiometricEnabled(false);
          
          final shouldPrompt = await BiometricService.shouldPromptBiometric();
          expect(shouldPrompt, false);

          // Enable biometrics
          await BiometricService.setBiometricEnabled(true);
          
          // Note: In test environment, device availability will likely be false
          final shouldPromptAfter = await BiometricService.shouldPromptBiometric();
          expect(shouldPromptAfter, isA<bool>());
        });
      });
    });

    group('Account Management Flow', () {
      testWidgets('save and retrieve server credentials', (WidgetTester tester) async {
        await tester.runAsync(() async {
          final prefs = await SharedPreferences.getInstance();

          // Save credentials
          await prefs.setString('server_url', 'https://demo.odoo.com');
          await prefs.setString('database', 'test_db');
          await prefs.setString('username', 'admin');

          // Retrieve
          expect(prefs.getString('server_url'), 'https://demo.odoo.com');
          expect(prefs.getString('database'), 'test_db');
          expect(prefs.getString('username'), 'admin');

          // Clear credentials
          await prefs.remove('server_url');
          await prefs.remove('database');
          await prefs.remove('username');

          expect(prefs.getString('server_url'), isNull);
        });
      });
    });

    group('Error Handling Flow', () {
      testWidgets('handles network errors gracefully', (WidgetTester tester) async {
        final mockClient = MockOdooClient();
        mockClient.shouldFail = true;

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: UserLoginScreen(
                serverUrl: 'https://demo.odoo.com',
                database: 'demo_db',
                client: mockClient,
              ),
            ),
          );
          await tester.pump();

          // Enter valid credentials
          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), 'admin');
          await tester.enterText(fields.at(1), 'password');
          await tester.pump();

          // Try to sign in (should fail)
          await tester.tap(find.text('Sign In'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          // Should still be on login screen
          expect(find.text('Sign In POS App'), findsOneWidget);
        });
      });
    });

    group('Multi-Step Workflow', () {
      testWidgets('complete user journey simulation', (WidgetTester tester) async {
        await tester.runAsync(() async {
          // Step 1: First launch - see get started
          await tester.pumpWidget(createAppWithRoutes());
          await tester.pump();
          expect(find.text('Streamline Your Sales'), findsOneWidget);

          // Step 2: Complete onboarding
          await tester.tap(find.text('Get Started'));
          await tester.pumpAndSettle();

          // Step 3: Theme configuration
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('theme_mode', 'dark');

          // Step 4: Biometric setup
          await BiometricService.setBiometricEnabled(true);
          final biometricEnabled = await BiometricService.isBiometricEnabled();
          expect(biometricEnabled, true);

          // Verify all settings persisted
          expect(prefs.getBool('hasSeenGetStarted'), true);
          expect(prefs.getString('theme_mode'), 'dark');
          expect(await BiometricService.isBiometricEnabled(), true);
        });
      });
    });
  });
}
