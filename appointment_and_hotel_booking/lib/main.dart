import 'package:flutter/material.dart';
import 'models/business_model.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_storage.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check saved session
  final bool loggedIn = await AuthStorage.isLoggedIn();
  final BusinessModel? business = loggedIn ? await AuthStorage.getBusiness() : null;

  runApp(MyApp(
    initialBusiness: business,
  ));
}

class MyApp extends StatelessWidget {
  final BusinessModel? initialBusiness;

  const MyApp({super.key, this.initialBusiness});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hotel & Appointment POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: initialBusiness != null
          ? HomeScreen(business: initialBusiness!)
          : const LoginScreen(),
    );
  }
}
