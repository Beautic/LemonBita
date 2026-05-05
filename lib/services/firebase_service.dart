import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
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
        // firebase_auth SDK 인증이 살아있는지 검증.
        fb_auth.User? sdkUser;
        try {
          sdkUser = fb_auth.FirebaseAuth.instance.currentUser;
        } catch (e) {
          // ignore: avoid_print
          print('[firebase_auth currentUser 조회 실패] $e');
          sdkUser = null;
        }
        if (sdkUser == null || sdkUser.uid != uid) {
          // SDK 인증 없음 → REST 세션 무효화하고 로그인 화면으로 유도
          // ignore: avoid_print
          print('[세션 복원] SDK 인증 없음 → REST 세션 무효화. 다시 로그인 필요.');
          await prefs.remove(_prefsKeyUid);
          await prefs.remove(_prefsKeyEmail);
          await prefs.remove(_prefsKeyIdToken);
          await prefs.remove(_prefsKeyRefreshToken);
          return;
        }
        _currentUser = AuthUser(
          uid: uid,
          email: email,
          idToken: idToken,
          refreshToken: refreshToken,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[세션 복원 예외] $e');
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
    // Firestore SDK가 request.auth를 인식하도록 firebase_auth SDK로도 로그인
    try {
      await fb_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // SDK 로그인 실패 시 진단 로그 (Firestore 권한이 깨질 수 있음)
      // ignore: avoid_print
      print('[firebase_auth SDK 로그인 실패] $e');
    }
    _authStateController.add(user);
    await _syncUserDocument(user);
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
    try {
      await fb_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // SDK 로그인 실패 시 진단 로그 (Firestore 권한이 깨질 수 있음)
      // ignore: avoid_print
      print('[firebase_auth SDK 로그인 실패] $e');
    }
    _authStateController.add(user);
    await _syncUserDocument(user);
    return user;
  }

  // 로그아웃
  Future<void> logout() async {
    _currentUser = null;
    await _clearSession();
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {}
    _authStateController.add(null);
  }

  // 사용자 정보 DB 연동
  Future<void> _syncUserDocument(AuthUser user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      String defaultName = user.email.split('@').first;
      await docRef.set({
        'email': user.email,
        'displayName': defaultName,
        'profileImageUrl': '',
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
        'followerCount': 0,
        'followingCount': 0,
        'postCount': 0,
        'totalLikesReceived': 0,
        'isPrivateAccount': false,
        'defaultOotdVisibility': 'public',
        'fcmTokens': [],
      });
    }
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
    required String subCategory,
    required String tags,
    String visibility = 'private',
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    await _firestore.collection('clothes').add({
      'userId': currentUserId,
      'imageUrl': imageUrl,
      'category': category,
      'subCategory': subCategory,
      'tags': tags,
      'visibility': visibility,
      '_publicMeta': visibility == 'public' ? {'category': category, 'subCategory': subCategory} : null,
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
    String visibility = 'private',
    bool requestFeedback = false,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    final hashtags = RegExp(r'#[\w가-힣]+').allMatches(description).map((m) => m.group(0)!).toList();

    await _firestore.collection('ootds').add({
      'userId': currentUserId,
      'userEmail': currentUser?.email,
      'imageUrl': imageUrl,
      'description': description,
      'taggedClothes': taggedClothes, // [{ id, imageUrl, title }, ...]
      'visibility': visibility,
      'requestFeedback': requestFeedback,
      'likeCount': 0,
      'commentCount': 0,
      'saveCount': 0,
      'hashtags': hashtags,
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

  // 7-1. Discover 피드 (전체 공개)
  Stream<QuerySnapshot> getDiscoverFeedStream() {
    return _firestore
        .collection('ootds')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 8. OOTD 삭제
  Future<void> deleteOOTDData(String docId) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    await _firestore.collection('ootds').doc(docId).delete();
  }

  // ==== 소셜 인터랙션 (Like) ====
  
  // 9. 좋아요 토글 (로컬에서 직접 트랜잭션 처리 임시 적용 가능, 본 앱은 Functions 권장)
  Future<void> toggleLike(String ootdId, bool isLiked) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    
    final likeRef = _firestore.collection('ootds').doc(ootdId).collection('likes').doc(currentUserId);
    
    if (isLiked) {
      await likeRef.delete();
      // Cloud Functions가 없는 경우를 대비한 로컬 카운트 처리 (옵션)
      // await _firestore.collection('ootds').doc(ootdId).update({'likeCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      // await _firestore.collection('ootds').doc(ootdId).update({'likeCount': FieldValue.increment(1)});
    }
  }

  // ==== 컬렉션(보드) 및 저장 (Save) ====

  // 10. 새 컬렉션(보드) 만들기
  Future<String> createCollection(String title, {bool isPrivate = false}) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    final docRef = await _firestore.collection('collections').add({
      'userId': currentUserId,
      'title': title,
      'coverImageUrl': '',
      'isPrivate': isPrivate,
      'ootdCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // 11. 내 컬렉션 스트림 가져오기
  Stream<QuerySnapshot> getCollectionsStream() {
    if (currentUserId == null) return const Stream.empty();
    return _firestore
        .collection('collections')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 12. OOTD 저장 토글 (Save)
  Future<void> toggleSave(String ootdId, bool isSaved, {String? collectionId}) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    
    final saveRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('savedOotds')
        .doc(ootdId);

    if (isSaved) {
      await saveRef.delete();
      if (collectionId != null) {
        await _firestore.collection('collections').doc(collectionId).update({
          'ootdCount': FieldValue.increment(-1)
        });
      }
    } else {
      await saveRef.set({
        'ootdId': ootdId,
        'collectionId': collectionId ?? 'default',
        'savedAt': FieldValue.serverTimestamp(),
      });
      if (collectionId != null) {
        // 커버 이미지를 업데이트하려면 여기서 해당 OOTD의 imageUrl을 가져와야 함
        final ootdDoc = await _firestore.collection('ootds').doc(ootdId).get();
        final imageUrl = ootdDoc.data()?['imageUrl'] ?? '';
        
        await _firestore.collection('collections').doc(collectionId).update({
          'ootdCount': FieldValue.increment(1),
          'coverImageUrl': imageUrl, // 가장 최근 저장된 사진으로 커버 업데이트
        });
      }
    }
  }

  // 13. 내가 저장한 OOTD 가져오기
  Stream<QuerySnapshot> getSavedOotdsStream({String? collectionId}) {
    if (currentUserId == null) return const Stream.empty();
    var query = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('savedOotds')
        .orderBy('savedAt', descending: true);
        
    if (collectionId != null) {
      query = query.where('collectionId', isEqualTo: collectionId);
    }
    
    return query.snapshots();
  }

  // ==== 팔로우 (Follow) ====

  // 14. 팔로우 토글
  Future<void> toggleFollow(String targetUserId, bool isFollowing) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    if (currentUserId == targetUserId) return; // 자기 자신 팔로우 방지

    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);

    final followingRef = currentUserRef.collection('following').doc(targetUserId);
    final followerRef = targetUserRef.collection('followers').doc(currentUserId);

    // Note: 완벽한 정합성을 위해서는 트랜잭션/배치 처리가 권장됩니다.
    if (isFollowing) {
      await followingRef.delete();
      await followerRef.delete();
      await currentUserRef.update({'followingCount': FieldValue.increment(-1)});
      await targetUserRef.update({'followerCount': FieldValue.increment(-1)});
    } else {
      await followingRef.set({'followedAt': FieldValue.serverTimestamp()});
      await followerRef.set({'followedAt': FieldValue.serverTimestamp()});
      await currentUserRef.update({'followingCount': FieldValue.increment(1)});
      await targetUserRef.update({'followerCount': FieldValue.increment(1)});
    }
  }

  // 15. 특정 유저 팔로우 여부 확인
  Stream<bool> isFollowingStream(String targetUserId) {
    if (currentUserId == null) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // 16. 팔로잉 피드 가져오기 (fan-in 방식, 30명 제한)
  Stream<QuerySnapshot> getFollowingFeedStream(List<String> followingIds) {
    if (followingIds.isEmpty) return const Stream.empty();
    
    // Firestore `whereIn`은 최대 30개 항목만 지원
    final idsToQuery = followingIds.take(30).toList();
    
    return _firestore
        .collection('ootds')
        .where('userId', whereIn: idsToQuery)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 내 팔로잉 ID 목록 가져오기 (1회성)
  Future<List<String>> getMyFollowingIds() async {
    if (currentUserId == null) return [];
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }
}
