import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  // Firebase 수동 초기화
  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
        authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN'],
      ),
    );
  }

  // 1. 이미지 데이터를 Storage에 업로드하고 URL 반환 (Uint8List 기반으로 웹 호환성 확보)
  Future<String> uploadImage(Uint8List fileBytes, String extension) async {
    String fileName = 'clothes/${DateTime.now().millisecondsSinceEpoch}.$extension';
    Reference ref = _storage.ref().child(fileName);

    // 웹에서는 putFile 대신 putData를 사용
    UploadTask uploadTask = ref.putData(
      fileBytes,
      SettableMetadata(contentType: 'image/$extension'),
    );

    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // 2. 옷 정보를 Firestore에 저장
  Future<void> saveClothingData({
    required String imageUrl,
    required String category,
    required String tags,
  }) async {
    await _firestore.collection('clothes').add({
      'imageUrl': imageUrl,
      'category': category,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // 3. 실시간으로 옷장 데이터 가져오기 (Stream)
  Stream<QuerySnapshot> getClothesStream() {
    return _firestore
        .collection('clothes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
