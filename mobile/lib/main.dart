import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: const MyrabaApp(),
    ),
  );
}

class MyrabaApp extends StatelessWidget {
  const MyrabaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Myraba',
      debugShowCheckedModeBanner: false,
      theme: myrabaTheme(),
      home: const SplashScreen(),
    );
  }
}
