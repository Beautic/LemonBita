import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await FirebaseService.initialize();
    runApp(const DigitalClosetApp());
  } catch (e, stackTrace) {
    debugPrint("🚩 Fatal Initialization Error: $e");
    debugPrint(stackTrace.toString());

    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableText("App Critical Error:\n$e"),
        ),
      ),
    ));
  }
}

class DigitalClosetApp extends StatelessWidget {
  const DigitalClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Myventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.ground,
        primaryColor: AppColors.ink,
        colorScheme: const ColorScheme.light(
          primary: AppColors.ink,
          secondary: AppColors.muted,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.ground,
          foregroundColor: AppColors.ink,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        fontFamily: 'Pretendard',
      ),
      home: const AuthWrapper(),
    );
  }
}

// 인증 상태를 감지하여 적절한 화면으로 강제 이동시키는 래퍼 위젯
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return StreamBuilder<AuthUser?>(
      stream: firebaseService.authStateChanges,
      initialData: firebaseService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
