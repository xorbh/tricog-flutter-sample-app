import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardioScanApp());
}

class CardioScanApp extends StatelessWidget {
  const CardioScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: 'pk_test_cm9tYW50aWMtaGVycmluZy05My5jbGVyay5hY2NvdW50cy5kZXYk',
      ),
      child: MaterialApp(
        title: 'CardioScan',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // When signed in, show the app
        ClerkSignedIn(
          child: FutureBuilder<bool>(
            future: DatabaseService.instance.hasProfile(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return snapshot.data! ? const HomeScreen() : const OnboardingScreen();
            },
          ),
        ),
        // When signed out, show the auth screen
        ClerkSignedOut(
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.monitor_heart, size: 64, color: Color(0xFF1565C0)),
                      const SizedBox(height: 12),
                      const Text(
                        'CardioScan',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 32),
                      const ClerkAuthentication(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
