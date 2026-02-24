import 'dart:io';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_pos/services/review_service.dart';
import 'package:provider/provider.dart';
import 'Isarmodel/Isar.dart';
import 'core/navigation/global_keys.dart';
import 'odoo_webapp/profile.dart';
import 'Loginpage/login.dart';
import 'Loginpage/splash.dart';
import 'Loginpage/server_setup_screen.dart';
import 'odoo_webapp/backend.dart';
import 'odoo_webapp/webapp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/biometric_service.dart';
import 'screens/biometric_auth_screen.dart';
import 'screens/get_started_screen.dart';
import 'providers/theme_provider.dart';
import 'core/motion_provider.dart';

String sessionId = "";
bool isLoggedIn = false;

// SSL Certificate bypass for development/testing
// WARNING: This bypasses SSL certificate validation - use only for development!
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return true; // Accept all certificates
      };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable SSL certificate bypass for development/testing
  // WARNING: Remove this in production or make it configurable
  HttpOverrides.global = MyHttpOverrides();
  
  await IsarService.instance;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MotionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          if (!themeProvider.isInitialized) {
            return const SizedBox.shrink();
          }
          
          return MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            debugShowCheckedModeBanner: false,
            title: 'Odoo Community POS',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFC03355),
                brightness: Brightness.light,
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 8,
                backgroundColor: Colors.white,
                titleTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
                contentTextStyle: const TextStyle(),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB00020), // uses error-like color in light
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 3,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6F6F6F), // onSurfaceVariant-like
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFC03355),
                brightness: Brightness.dark,
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
                backgroundColor: Colors.grey[900],
                titleTextStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                contentTextStyle: TextStyle(
                  color: Colors.grey[300],
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[400],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            initialRoute: '/',
            routes: {
              '/':(context) => const SplashScreen(),
              '/get_started': (context) => const GetStartedScreen(),
              '/server_setup': (context) => const ServerSetupScreen(),
              '/init': (context) => const FutureBuilderPage(),
              '/login': (context) => LoginPage(),
              '/webapp': (context) => WebViewApp(),
              '/future': (context) => const FutureBuilderPage(),
              '/profile': (context) => ProfilePage(),
              '/backend': (context) => BackendPage(),
              '/biometric': (context) => BiometricAuthScreen(
                onAuthenticationSuccess: () {
                  Navigator.of(context).pushReplacementNamed('/webapp');
                },
              ),
            },
          );
        },
      ),
    );
  }
}

class FutureBuilderPage extends StatefulWidget {
  const FutureBuilderPage({super.key});

  @override
  State<FutureBuilderPage> createState() => _FutureBuilderPageState();
}

class _FutureBuilderPageState extends State<FutureBuilderPage> with WidgetsBindingObserver {
  bool _isAppInBackground = false;
  bool _shouldShowBiometric = false;

  @override
  void initState() {
    super.initState();
    // Track app open for review system after a delay to ensure activity is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        ReviewService().trackAppOpen();
      });
    });
  }

  Future<Map<String, dynamic>> _futurePath() async {
    final prefs = await SharedPreferences.getInstance();
    var sessionId = prefs.getString("session_id");
    var serverUrl = prefs.getString("uri") ?? "";
    var database = prefs.getString("database") ?? "";
    var posId = prefs.getInt("pos_id");


    // Check if biometric authentication should be prompted
    bool shouldPromptBiometric = await BiometricService.shouldPromptBiometric();

    return {
      "hasSession": sessionId != null,
      "serverUrl": serverUrl,
      "database": database,
      "posId": posId,
      "shouldPromptBiometric": shouldPromptBiometric,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _futurePath(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading indicator while waiting
          return Scaffold(
            body: Container(
              color: Colors.grey[50],
              child: Center(
                child: LoadingAnimationWidget.staggeredDotsWave(
                  color: Color(0xFFC03355),
                  size: 40,
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          // Handle any errors that may occur
          return Scaffold(
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        } else if (snapshot.hasData) {
          var hasSession = snapshot.data!["hasSession"];
          var serverUrl = snapshot.data!["serverUrl"];
          var database = snapshot.data!["database"];
          var posId = snapshot.data!["posId"];
          var shouldPromptBiometric = snapshot.data!["shouldPromptBiometric"] ?? false;
          
          // If biometric authentication is enabled and user has a session, show biometric screen first
          if (shouldPromptBiometric && hasSession == true) {
            return BiometricAuthScreen(
              onAuthenticationSuccess: () {
                // Navigate to appropriate screen after successful authentication
                if (posId != null) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => WebViewApp()),
                  );
                } else {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => BackendPage()),
                  );
                }
              },
            );
          }
          
          if (hasSession == true) {
            // If session exists, check if POS configuration is selected
            if (posId != null) {
              return WebViewApp();
            } else {
              return BackendPage();
            }
          } else {
            // If no session, check if server configuration exists
            if (serverUrl.isEmpty || database.isEmpty) {
              return ServerSetupScreen();
            } else {
              return LoginPage(
                serverUrl: serverUrl,
                database: database,
              );
            }
          }
        } else {
          // Fallback in case of unexpected behavior
          return const Scaffold(
            body: Center(
              child: Text("Something went wrong!"),
            ),
          );
        }
      },
    );
  }
}
