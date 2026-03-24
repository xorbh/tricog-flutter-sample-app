import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardioScanApp());
}

class CardioScanApp extends StatelessWidget {
  const CardioScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CardioScan',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
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
    );
  }
}
