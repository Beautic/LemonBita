import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String uid;
  final String email;
  final String idToken;
  final String refreshToken;

  AuthUser({
    required this.uid,
    required this.email,
    required this.idToken,
    required this.refreshToken,
  });
}

class FirebaseService {
  static const String _apiKey = "AIzaSyA53XksiSaTI_S7TjENSv1J_slbSOWTwPg";

  // 인증 상태 관리
  static AuthUser? _currentUser;
  static final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();

  // SharedPreferences 키
  static const String _prefsKeyUid = 'auth_uid';
  static const String _prefsKeyEmail = 'auth_email';
  static const String _prefsKeyIdToken = 'auth_idToken';
  static const String _prefsKeyRefreshToken = 'auth_refreshToken';

  // Firebase 초기화 (플랫폼별 분기)
  static Future<void> initialize() async {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: "1:891078999530:web:12ba98b8ab107e5ef24693",
          messagingSenderId: "891078999530",
          projectId: "digital-closet-32c43",
          storageBucket: "digital-closet-32c43.firebasestorage.app",
          authDomain: "digital-closet-32c43.web.app",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    // 디스크에 저장된 로그인 상태 복원
    await _restoreSession();
    // 초기 상태 emit
    _authStateController.add(_currentUser);
  }

  // 디스크에서 세션 복원 (앱 시작 시 호출)
  static Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_prefsKeyUid);
      final email = prefs.getString(_prefsKeyEmail);
      final idToken = prefs.getString(_prefsKeyIdToken);
      final refreshToken = prefs.getString(_prefsKeyRefreshToken);
      if (uid != null &&
          email != null &&
          idToken != null &&
          refreshToken != null) {
        _currentUser = AuthUser(
          uid: uid,
          email: email,
          idToken: idToken,
          refreshToken: refreshToken,
        );
      }
    } catch (_) {
      // 복원 실패 시 무시 (로그인 화면으로 떨어짐)
    }
  }

  // 디스크에 세션 저장 (로그인/회원가입 성공 시 호출)
  static Future<void> _persistSession(AuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyUid, user.uid);
    await prefs.setString(_prefsKeyEmail, user.email);
    await prefs.setString(_prefsKeyIdToken, user.idToken);
    await prefs.setString(_prefsKeyRefreshToken, user.refreshToken);
  }

  // 디스크에서 세션 삭제 (로그아웃 시 호출)
  static Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyUid);
    await prefs.remove(_prefsKeyEmail);
    await prefs.remove(_prefsKeyIdToken);
    await prefs.remove(_prefsKeyRefreshToken);
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==== 인증(Auth) 관련 로직 (REST API) ====

  // 로그인 상태 구독 스트림 (라우팅용)
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  // 현재 유저 ID 가져오기
  String? get currentUserId => _currentUser?.uid;

  // 현재 유저 가져오기
  AuthUser? get currentUser => _currentUser;

  // 이메일 회원가입 (REST API)
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    final response = await http.post(
      Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw _parseAuthError(data);
    }

    final user = AuthUser(
      uid: data['localId'],
      email: data['email'],
      idToken: data['idToken'],
      refreshToken: data['refreshToken'],
    );
    _currentUser = user;
    await _persistSession(user);
    _authStateController.add(user);
    return user;
  }

  // 이메일 로그인 (REST API)
  Future<AuthUser> loginWithEmail(String email, String password) async {
    final response = await http.post(
      Uri.parse(
          'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw _parseAuthError(data);
    }

    final user = AuthUser(
      uid: data['localId'],
      email: data['email'],
      idToken: data['idToken'],
      refreshToken: data['refreshToken'],
    );
    _currentUser = user;
    await _persistSession(user);
    _authStateController.add(user);
    return user;
  }

  // 로그아웃
  Future<void> logout() async {
    _currentUser = null;
    await _clearSession();
    _authStateController.add(null);
  }

  // Firebase Auth REST API 에러 파싱
  Exception _parseAuthError(Map<String, dynamic> data) {
    final errorMessage =
        data['error']?['message'] ?? 'Unknown error';
    switch (errorMessage) {
      case 'EMAIL_EXISTS':
        return Exception('이미 등록된 이메일입니다.');
      case 'INVALID_EMAIL':
        return Exception('유효하지 않은 이메일 형식입니다.');
      case 'WEAK_PASSWORD':
        return Exception('비밀번호가 너무 약합니다. (6자 이상)');
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return Exception('이메일 또는 비밀번호가 올바르지 않습니다.');
      case 'USER_DISABLED':
        return Exception('비활성화된 계정입니다.');
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return Exception('너무 많은 시도. 잠시 후 다시 시도하세요.');
      default:
        return Exception('인증 오류: $errorMessage');
    }
  }

  // ==== 데이터베이스 및 스토리지 관련 로직 ====

  // 1. 이미지 데이터를 Storage에 업로드하고 URL 반환
  Future<String> uploadImage(Uint8List fileBytes, String extension) async {
    String fileName =
        'clothes/${DateTime.now().millisecondsSinceEpoch}.$extension';
    Reference ref = _storage.ref().child(fileName);

    UploadTask uploadTask = ref.putData(
      fileBytes,
      SettableMetadata(contentType: 'image/$extension'),
    );

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // 2. 옷 정보를 Firestore에 저장 (현재 유저 uid와 연결)
  Future<void> saveClothingData({
    required String imageUrl,
    required String category,
    required String tags,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    await _firestore.collection('clothes').add({
      'userId': currentUserId,
      'imageUrl': imageUrl,
      'category': category,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. 실시간으로 '내' 옷장 데이터만 가져오기 (Stream)
  Stream<QuerySnapshot> getClothesStream() {
    if (currentUserId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('clothes')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 4. 옷 정보 업데이트
  Future<void> updateClothingData({
    required String docId,
    required Map<String, dynamic> updatedData,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    await _firestore.collection('clothes').doc(docId).update(updatedData);
  }

  // 5. 옷 삭제
  Future<void> deleteClothingData(String docId) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    await _firestore.collection('clothes').doc(docId).delete();
  }

  // ==== OOTD 관련 로직 ====

  // 6. OOTD 저장 (태그된 옷 정보 포함)
  Future<void> saveOOTDData({
    required String imageUrl,
    required String description,
    required List<Map<String, dynamic>> taggedClothes,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    await _firestore.collection('ootds').add({
      'userId': currentUserId,
      'imageUrl': imageUrl,
      'description': description,
      'taggedClothes': taggedClothes, // [{ id, imageUrl, title }, ...]
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 7. 실시간 OOTD 피드 스트림
  Stream<QuerySnapshot> getOOTDStream() {
    if (currentUserId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('ootds')
        .where('userId', isEqualTo: currentUserId)
        .snapshots();
  }

  // 8. OOTD 삭제
  Future<void> deleteOOTDData(String docId) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    await _firestore.collection('ootds').doc(docId).delete();
  }
}
