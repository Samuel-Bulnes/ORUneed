/*
 * Samuel Bulnes
 * Senior Project
 * Main file
 * Everything starts from here.
*/

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';

//***********************************************************************************
// Application entry point
// This function runs before the app starts and initializes Firebase
void main() async {
  // Ensures Flutter bindings are initialized before Firebase is used
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using platform-specific configuration
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Start the Flutter application
  runApp(const MyApp());
}

//***********************************************************************************
// Root widget of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORUneed',
      debugShowCheckedModeBanner: false, // Removes debug banner in top-right corner

      // Global theme configuration - Dark theme
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00D9FF), // Neon blue
        scaffoldBackgroundColor: const Color(0xFF000000), // Pure black background
        cardColor: const Color(0xFF1A1F2E), // Dark card background
        useMaterial3: true,
        
        // Text theme for dark mode
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFFFFFFF)),
          bodySmall: TextStyle(color: Color(0xFFB0B0B0)),
          headlineSmall: TextStyle(color: Color(0xFFFFFFFF)),
          headlineMedium: TextStyle(color: Color(0xFFFFFFFF)),
          headlineLarge: TextStyle(color: Color(0xFFFFFFFF)),
          labelLarge: TextStyle(color: Color(0xFFFFFFFF)),
          labelMedium: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        
        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1F2E),
          labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
          hintStyle: const TextStyle(color: Color(0xFF666666)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00D9FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF00FFFF), width: 2),
          ),
        ),
      ),

      // First widget shown: decides to show login or home
      home: const AuthWrapper(),

      // App routes
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

//***********************************************************************************
// Authentication wrapper that manages app navigation based on login state
// This widget listens to Firebase Auth and automatically switches between
// login and home screens when the user signs in or out
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

//***********************************************************************************
// Authentications 
class _AuthWrapperState extends State<AuthWrapper> {
  final authService = AuthService();       // handles Firebase authentication
  final socketService = SocketService();   // manages socket.io real-time connection

  @override
  void dispose() {
    // Ensures socket disconnection when widget is destroyed
    socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Listens to login/logout events from Firebase Auth
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        
        // Firebase still initializing user session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Logged-in state (Firebase user exists)
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          // Connect socket only ONCE after login
          if (!socketService.isConnected) {
            // Wait until UI frame is built to avoid calling setState inside build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              socketService.connect(user.uid);
            });
          }

          // Redirect to home page
          return const HomeScreen();
        }

        // Logged-out state: ensure socket is disconnected
        if (socketService.isConnected) {
          socketService.disconnect();
        }

        // Redirect to login page
        return const LoginScreen();
      },
    );
  }
}
