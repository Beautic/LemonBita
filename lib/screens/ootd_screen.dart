import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';

class OotdScreen extends StatefulWidget {
  const OotdScreen({super.key});

  @override
  State<OotdScreen> createState() => _OotdScreenState();
}

class _OotdScreenState extends State<OotdScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<QuerySnapshot> _ootdStream;

  @override
  void initState() {
    super.initState();
    _ootdStream = _firebaseService.getOOTDStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'OOTD',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ootdStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (snapshot.hasError) {
            return Center(child: Text('에러가 발생했습니다: ${snapshot.error}'));
          }

          var ootds = snapshot.data?.docs.toList() ?? [];
          
          // 로컬 정렬 (Firestore 복합 인덱스 에러 방지)
          ootds.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (ootds.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('첫 번째 OOTD를 기록해보세요!', 
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: ootds.length,
            separatorBuilder: (context, index) => const Divider(height: 32, thickness: 8, color: Color(0xFFF5F5F5)),
            itemBuilder: (context, index) {
              final doc = ootds[index];
              final item = doc.data() as Map<String, dynamic>;
              return _buildOotdPost(doc.id, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildOotdPost(String docId, Map<String, dynamic> item) {
    // Timestamp 변환
    String dateStr = '';
    if (item['createdAt'] != null) {
      final dt = (item['createdAt'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy년 MM월 dd일').format(dt);
    }

    // 태그된 옷 파싱
    List<dynamic> taggedClothes = item['taggedClothes'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 헤더 (날짜)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'My Daily Look',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),

        // 2. 이미지
        Container(
          width: double.infinity,
          height: 400,
          color: Colors.grey[100],
          child: Image.network(
            item['imageUrl'] ?? '',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),

        // 3. 코멘트 영역
        if ((item['description'] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              item['description'],
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),

        // 4. 태그된 옷 영역
        if (taggedClothes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sell, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('이 OOTD에 입은 옷', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: taggedClothes.length,
                    itemBuilder: (context, index) {
                      final cloth = taggedClothes[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(cloth['imageUrl'] ?? ''),
                              backgroundColor: Colors.grey[200],
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                cloth['title'] ?? '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
