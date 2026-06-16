import 'package:firebase_core/firebase_core.dart';

/// 운영(prod) / 개발(dev) 환경 전환 설정.
///
/// 빌드/실행 시 `--dart-define=ENV=prod` 또는 `--dart-define=ENV=dev` 로 지정합니다.
/// 기본값은 **dev** 입니다. (로컬 `flutter run` 시 실수로 운영 데이터를 건드리지 않도록)
/// 운영 배포는 deploy 스크립트에서 항상 명시적으로 `ENV=prod` 를 전달합니다.
class FirebaseEnv {
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProd => env == 'prod';
  static bool get isDev => !isProd;

  /// 운영계 (기존 digital-closet-32c43)
  static const FirebaseOptions _prod = FirebaseOptions(
    apiKey: "AIzaSyA53XksiSaTI_S7TjENSv1J_slbSOWTwPg",
    appId: "1:891078999530:web:12ba98b8ab107e5ef24693",
    messagingSenderId: "891078999530",
    projectId: "digital-closet-32c43",
    storageBucket: "digital-closet-32c43.firebasestorage.app",
    authDomain: "digital-closet-32c43.web.app",
  );

  /// 개발계 (digital-closet-dev)
  static const FirebaseOptions _dev = FirebaseOptions(
    apiKey: "AIzaSyB5RU_GjAXjgk55-GtMxN9QXNORkQh1q0I",
    appId: "1:218251473508:web:18bdd385aa7600fb96e571",
    messagingSenderId: "218251473508",
    projectId: "digital-closet-dev",
    storageBucket: "digital-closet-dev.firebasestorage.app",
    authDomain: "digital-closet-dev.firebaseapp.com",
  );

  static FirebaseOptions get options => isProd ? _prod : _dev;
}
