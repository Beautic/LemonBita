import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

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
      title: 'My Digital Closet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.black,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        fontFamily: 'Roboto',
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
