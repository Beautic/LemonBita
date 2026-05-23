import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart' show kIsWeb;

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
    
    // FirebaseAuth의 인증 상태 변화를 구독
    auth.FirebaseAuth.instance.authStateChanges().listen((auth.User? user) {
      if (user != null) {
        _currentUser = AuthUser(
          uid: user.uid,
          email: user.email ?? '',
          idToken: '', // 더 이상 SDK 외부에서 사용 안함
          refreshToken: '', // 더 이상 SDK 외부에서 사용 안함
        );
        _authStateController.add(_currentUser);
      } else {
        _currentUser = null;
        _authStateController.add(null);
      }
    });
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

  // 이메일 회원가입 (기본)
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    try {
      final cred = await auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = AuthUser(
        uid: cred.user!.uid,
        email: cred.user!.email ?? '',
        idToken: '',
        refreshToken: '',
      );
      return user;
    } on auth.FirebaseAuthException catch (e) {
      throw _parseAuthError(e);
    }
  }

  // 상세 정보 포함 회원가입
  Future<void> signUpWithDetails({
    required String email,
    required String password,
    required String realName,
    required String phoneNumber,
    required String nickname,
    required bool agreedToTerms,
    Uint8List? profileImageBytes,
  }) async {
    try {
      final cred = await auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      String profileImageUrl = '';
      if (profileImageBytes != null) {
        profileImageUrl = await uploadImage(profileImageBytes, 'jpg');
      }

      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'realName': realName,
        'phoneNumber': phoneNumber,
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        'agreedToTerms': agreedToTerms,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } on auth.FirebaseAuthException catch (e) {
      throw _parseAuthError(e);
    }
  }

  // 프로필 정보 업데이트
  Future<void> updateUserProfile({
    required String nickname,
    Uint8List? profileImageBytes,
    String? existingImageUrl,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    
    String imageUrl = existingImageUrl ?? '';
    
    if (profileImageBytes != null) {
      imageUrl = await uploadImage(profileImageBytes, 'jpg');
    }

    await _firestore.collection('users').doc(currentUserId).update({
      'nickname': nickname,
      'profileImageUrl': imageUrl,
    });
  }

  // 프로필 정보 스트림
  Stream<DocumentSnapshot> getUserProfileStream() {
    if (currentUserId == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUserId).snapshots();
  }

  // 이메일 로그인
  Future<AuthUser> loginWithEmail(String email, String password) async {
    try {
      final cred = await auth.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = AuthUser(
        uid: cred.user!.uid,
        email: cred.user!.email ?? '',
        idToken: '',
        refreshToken: '',
      );
      return user;
    } on auth.FirebaseAuthException catch (e) {
      throw _parseAuthError(e);
    }
  }

  // 로그아웃
  Future<void> logout() async {
    await auth.FirebaseAuth.instance.signOut();
  }

  // Firebase Auth SDK 에러 파싱
  Exception _parseAuthError(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return Exception('이미 등록된 이메일입니다.');
      case 'invalid-email':
        return Exception('유효하지 않은 이메일 형식입니다.');
      case 'weak-password':
        return Exception('비밀번호가 너무 약합니다. (6자 이상)');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return Exception('이메일 또는 비밀번호가 올바르지 않습니다.');
      case 'user-disabled':
        return Exception('비활성화된 계정입니다.');
      case 'too-many-requests':
        return Exception('너무 많은 시도. 잠시 후 다시 시도하세요.');
      default:
        return Exception('인증 오류: ${e.message}');
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

  // 1-1. 스토리지에서 이미지 다운로드 (raw XHR — Storage bucket의 CORS 정책 필요)
  Future<Uint8List?> downloadImage(String url) async {
    if (url.isEmpty) {
      throw Exception('Image URL is empty');
    }
    final completer = Completer<Uint8List>();
    final request = html.HttpRequest()
      ..open('GET', url)
      ..responseType = 'arraybuffer';

    request.onLoad.listen((_) {
      final status = request.status ?? 0;
      if (status >= 200 && status < 300) {
        final buf = request.response as ByteBuffer;
        completer.complete(buf.asUint8List());
      } else {
        completer.completeError(
          Exception('HTTP $status ${request.statusText ?? ""}'),
        );
      }
    });

    request.onError.listen((_) {
      final status = request.status ?? 0;
      completer.completeError(
        Exception('Network/CORS error (status=$status)'),
      );
    });

    request.send();
    return await completer.future;
  }

  // 2. 옷 정보를 Firestore에 저장 (현재 유저 uid와 연결)
  Future<void> saveClothingData({
    required String imageUrl,
    required String category,
    required String subCategory,
    required String tags,
    String? color,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    await _firestore.collection('clothes').add({
      'userId': currentUserId,
      'imageUrl': imageUrl,
      'category': category,
      'subCategory': subCategory,
      'tags': tags,
      'color': color ?? '',
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

  // 6.5 기존 OOTD에 옷 태그 일괄 연결/해제
  Future<void> updateOOTDClothesTags({
    required String clothingId,
    required Map<String, dynamic> clothingItemData,
    required List<String> selectedOotdIds,
    required List<String> originalOotdIds,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    final toAdd = selectedOotdIds.where((id) => !originalOotdIds.contains(id)).toList();
    final toRemove = originalOotdIds.where((id) => !selectedOotdIds.contains(id)).toList();

    String title = '${clothingItemData['color'] ?? ''} ${clothingItemData['pattern'] ?? ''}'.trim();
    if (title.isEmpty) title = clothingItemData['brand'] ?? '';
    if (title.isEmpty) title = clothingItemData['category'] ?? '옷 정보 없음';

    final tagObject = {
      'id': clothingId,
      'imageUrl': clothingItemData['imageUrl'],
      'title': title,
    };

    // 추가할 OOTD 처리
    for (var docId in toAdd) {
      final docRef = _firestore.collection('ootds').doc(docId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        
        final data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> taggedClothes = List.from(data['taggedClothes'] ?? []);
        List<dynamic> taggedClothesIds = List.from(data['taggedClothesIds'] ?? []);
        
        if (!taggedClothesIds.contains(clothingId)) {
          taggedClothesIds.add(clothingId);
          taggedClothes.add(tagObject);
          transaction.update(docRef, {
            'taggedClothes': taggedClothes,
            'taggedClothesIds': taggedClothesIds,
          });
        }
      });
    }

    // 제거할 OOTD 처리
    for (var docId in toRemove) {
      final docRef = _firestore.collection('ootds').doc(docId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        
        final data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> taggedClothes = List.from(data['taggedClothes'] ?? []);
        List<dynamic> taggedClothesIds = List.from(data['taggedClothesIds'] ?? []);
        
        taggedClothesIds.remove(clothingId);
        taggedClothes.removeWhere((item) => item is Map && item['id'] == clothingId);
        
        transaction.update(docRef, {
          'taggedClothes': taggedClothes,
          'taggedClothesIds': taggedClothesIds,
        });
      });
    }
  }

  // 6. OOTD 저장 (태그된 옷 정보 포함)
  Future<void> saveOOTDData({
    required String imageUrl,
    required String description,
    required List<Map<String, dynamic>> taggedClothes,
    DateTime? date,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    List<String> taggedClothesIds = taggedClothes.map((cloth) => cloth['id'] as String).toList();

    await _firestore.collection('ootds').add({
      'userId': currentUserId,
      'imageUrl': imageUrl,
      'description': description,
      'taggedClothes': taggedClothes, // [{ id, imageUrl, title }, ...]
      'taggedClothesIds': taggedClothesIds,
      'createdAt': date != null ? Timestamp.fromDate(date) : FieldValue.serverTimestamp(),
    });
  }

  // 6-1. OOTD 날짜 수정
  Future<void> updateOOTDDate(String docId, DateTime newDate) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    await _firestore.collection('ootds').doc(docId).update({
      'createdAt': Timestamp.fromDate(newDate),
    });
  }

  // 6-1. OOTD 태그 수정
  Future<void> updateOOTDTags(String docId, List<Map<String, dynamic>> newTaggedClothes) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    
    List<String> taggedClothesIds = newTaggedClothes.map((cloth) => cloth['id'] as String).toList();

    await _firestore.collection('ootds').doc(docId).update({
      'taggedClothes': newTaggedClothes,
      'taggedClothesIds': taggedClothesIds,
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

  // ==== OOTD 최적화 조회 로직 (Pagination & Monthly) ====

  // 9. OOTD 페이지네이션 조회 (무한 스크롤 용)
  Future<List<QueryDocumentSnapshot>> getOOTDPage({DocumentSnapshot? lastDoc, int limit = 10}) async {
    if (currentUserId == null) return [];

    Query query = _firestore
        .collection('ootds')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  // 10. 특정 월의 OOTD 데이터만 조회 (달력 용)
  Future<List<QueryDocumentSnapshot>> getOOTDsByMonth(int year, int month) async {
    if (currentUserId == null) return [];

    // 해당 월의 시작일과 다음 달의 시작일 구하기
    final startOfMonth = DateTime.utc(year, month, 1);
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final startOfNextMonth = DateTime.utc(nextYear, nextMonth, 1);

    final snapshot = await _firestore
        .collection('ootds')
        .where('userId', isEqualTo: currentUserId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('createdAt', isLessThan: Timestamp.fromDate(startOfNextMonth))
        .get();

    return snapshot.docs;
  }

  // ==== 예비 OOTD (코디 캔버스) 관련 로직 ====

  Future<void> savePlannedOOTDData({
    required Uint8List imageBytes,
    required List<Map<String, dynamic>> taggedClothes,
    required List<Map<String, dynamic>> canvasItems,
    String? targetUserId,
    String? docId,
  }) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");

    final uid = targetUserId ?? currentUserId!;
    
    String? suggestedBy;
    if (targetUserId != null && targetUserId != currentUserId) {
      final myProfile = await _firestore.collection('users').doc(currentUserId).get();
      suggestedBy = myProfile.data()?['nickname'];
    }

    String imageUrl = await uploadImage(imageBytes, 'png');

    final data = {
      'userId': uid,
      'imageUrl': imageUrl,
      'taggedClothes': taggedClothes,
      'canvasItems': canvasItems,
      if (suggestedBy != null) 'suggestedBy': suggestedBy,
    };

    if (docId != null) {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('planned_ootds').doc(docId).update(data);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('planned_ootds').add(data);
      
      if (targetUserId != null && targetUserId != currentUserId && suggestedBy != null) {
        await sendNotification(
          recipientId: targetUserId,
          type: 'outfit_suggestion',
          message: '$suggestedBy님이 코디를 추천했습니다!',
          targetId: '',
        );
      }
    }
  }

  Future<List<QueryDocumentSnapshot>> getPlannedOOTDPage({DocumentSnapshot? lastDoc, int limit = 10}) async {
    if (currentUserId == null) return [];

    // 복합 인덱스(Composite Index) 에러를 방지하기 위해 
    // 로컬에서 정렬하는 방식으로 변경합니다.
    Query query = _firestore
        .collection('planned_ootds')
        .where('userId', isEqualTo: currentUserId);

    final snapshot = await query.get();
    
    // 로컬 메모리에서 최신순 정렬
    List<QueryDocumentSnapshot> docs = snapshot.docs;
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['createdAt'] as Timestamp?;
      final bTime = bData['createdAt'] as Timestamp?;
      
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    // 페이징 처리 (클라이언트 사이드)
    int startIndex = 0;
    if (lastDoc != null) {
      final idx = docs.indexWhere((doc) => doc.id == lastDoc.id);
      if (idx != -1) startIndex = idx + 1;
    }

    int endIndex = startIndex + limit;
    if (endIndex > docs.length) endIndex = docs.length;

    if (startIndex >= docs.length) return [];
    return docs.sublist(startIndex, endIndex);
  }

  Future<void> deletePlannedOOTDData(String docId) async {
    if (currentUserId == null) throw Exception("로그인이 필요합니다.");
    await _firestore.collection('planned_ootds').doc(docId).delete();
  }

  // ==== 마이크로 소셜 (친구, 알림, 댓글) ====

  // 1. 사용자 검색 (이메일, 폰번호, 닉네임)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    // 단순화를 위해 병렬 쿼리 후 병합
    final byEmail = await _firestore.collection('users').where('email', isEqualTo: query).get();
    final byPhone = await _firestore.collection('users').where('phoneNumber', isEqualTo: query).get();
    final byNickname = await _firestore.collection('users').where('nickname', isEqualTo: query).get();

    final Map<String, Map<String, dynamic>> results = {};
    for (var doc in [...byEmail.docs, ...byPhone.docs, ...byNickname.docs]) {
      if (doc.id == currentUserId) continue; // 본인 제외
      final data = doc.data();
      data['uid'] = doc.id;
      results[doc.id] = data;
    }
    return results.values.toList();
  }

  // 2. 친구 요청 보내기
  Future<void> sendFriendRequest(String toUserId) async {
    if (currentUserId == null) return;
    
    final myProfile = await _firestore.collection('users').doc(currentUserId).get();
    final myData = myProfile.data() ?? {};

    await _firestore.collection('users').doc(toUserId).collection('friend_requests').doc(currentUserId).set({
      'uid': currentUserId,
      'nickname': myData['nickname'],
      'profileImageUrl': myData['profileImageUrl'],
      'createdAt': FieldValue.serverTimestamp(),
    });

    await sendNotification(
      recipientId: toUserId,
      type: 'friend_request',
      message: '${myData['nickname']}님이 친구 요청을 보냈습니다.',
      targetId: currentUserId!,
    );
  }

  // 3. 친구 요청 수락
  Future<void> acceptFriendRequest(String fromUserId) async {
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    
    final myRef = _firestore.collection('users').doc(currentUserId);
    final friendRef = _firestore.collection('users').doc(fromUserId);
    final requestRef = _firestore.collection('users').doc(currentUserId).collection('friend_requests').doc(fromUserId);

    batch.update(myRef, {'friends': FieldValue.arrayUnion([fromUserId])});
    batch.update(friendRef, {'friends': FieldValue.arrayUnion([currentUserId])});
    batch.delete(requestRef);
    
    await batch.commit();

    final myProfile = await myRef.get();
    final myData = myProfile.data() ?? {};
    
    await sendNotification(
      recipientId: fromUserId,
      type: 'friend_accept',
      message: '${myData['nickname']}님이 친구 요청을 수락했습니다.',
      targetId: currentUserId!,
    );
  }

  Future<void> rejectFriendRequest(String fromUserId) async {
    if (currentUserId == null) return;
    await _firestore.collection('users').doc(currentUserId).collection('friend_requests').doc(fromUserId).delete();
  }

  // 4. 내 친구 목록 가져오기
  Future<List<Map<String, dynamic>>> getFriends() async {
    if (currentUserId == null) return [];
    final myDoc = await _firestore.collection('users').doc(currentUserId).get();
    final List<dynamic> friendUids = myDoc.data()?['friends'] ?? [];
    
    if (friendUids.isEmpty) return [];

    final snapshot = await _firestore.collection('users').where(FieldPath.documentId, whereIn: friendUids.take(10).toList()).get();
    return snapshot.docs.map((d) {
      final data = d.data();
      data['uid'] = d.id;
      return data;
    }).toList();
  }
  
  Stream<QuerySnapshot> getFriendRequestsStream() {
    if (currentUserId == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUserId).collection('friend_requests').orderBy('createdAt', descending: true).snapshots();
  }

  // 5. 알림 보내기
  Future<void> sendNotification({
    required String recipientId,
    required String type,
    required String message,
    required String targetId,
  }) async {
    if (currentUserId == null || currentUserId == recipientId) return;

    final myProfile = await _firestore.collection('users').doc(currentUserId).get();
    final myData = myProfile.data() ?? {};

    await _firestore.collection('users').doc(recipientId).collection('notifications').add({
      'senderId': currentUserId,
      'senderNickname': myData['nickname'],
      'senderProfileUrl': myData['profileImageUrl'],
      'type': type,
      'message': message,
      'targetId': targetId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNotificationsStream() {
    if (currentUserId == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUserId).collection('notifications')
        .orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> markNotificationAsRead(String notifId) async {
    if (currentUserId == null) return;
    await _firestore.collection('users').doc(currentUserId).collection('notifications').doc(notifId).update({'isRead': true});
  }

  // 6. OOTD 좋아요 토글
  Future<void> toggleOotdLike(String ootdId, String ownerId, bool isCurrentlyLiked) async {
    if (currentUserId == null) return;

    final ref = _firestore.collection('ootds').doc(ootdId);
    if (isCurrentlyLiked) {
      await ref.update({'likedBy': FieldValue.arrayRemove([currentUserId])});
    } else {
      await ref.update({'likedBy': FieldValue.arrayUnion([currentUserId])});
      await sendNotification(
        recipientId: ownerId,
        type: 'ootd_like',
        message: '회원님의 OOTD를 좋아합니다.',
        targetId: ootdId,
      );
    }
  }

  // 7. OOTD 댓글 쓰기
  Future<void> addOotdComment(String ootdId, String ownerId, String text, {String? replyToId}) async {
    if (currentUserId == null) return;
    
    final myProfile = await _firestore.collection('users').doc(currentUserId).get();
    final myData = myProfile.data() ?? {};

    await _firestore.collection('ootds').doc(ootdId).collection('comments').add({
      'userId': currentUserId,
      'nickname': myData['nickname'],
      'profileImageUrl': myData['profileImageUrl'],
      'text': text,
      'replyToId': replyToId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await sendNotification(
      recipientId: ownerId,
      type: 'ootd_comment',
      message: '회원님의 OOTD에 댓글을 남겼습니다.',
      targetId: ootdId,
    );
  }

  Stream<QuerySnapshot> getOotdCommentsStream(String ootdId) {
    return _firestore.collection('ootds').doc(ootdId).collection('comments').orderBy('createdAt', descending: false).snapshots();
  }

  // 8. 친구 OOTD 피드
  Future<List<QueryDocumentSnapshot>> getFriendsOotdFeed() async {
    if (currentUserId == null) return [];
    final myDoc = await _firestore.collection('users').doc(currentUserId).get();
    final List<dynamic> friendUids = myDoc.data()?['friends'] ?? [];
    
    if (friendUids.isEmpty) return [];

    final snapshot = await _firestore.collection('ootds')
        .where('userId', whereIn: friendUids.take(10).toList())
        .get();
        
    List<QueryDocumentSnapshot> docs = snapshot.docs;
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['createdAt'] as Timestamp?;
      final bTime = bData['createdAt'] as Timestamp?;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    
    return docs;
  }
}
