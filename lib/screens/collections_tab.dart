import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class CollectionsTab extends StatelessWidget {
  const CollectionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return StreamBuilder<QuerySnapshot>(
      stream: firebaseService.getCollectionsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('저장된 컬렉션이 없습니다.', style: TextStyle(color: Colors.grey)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final coverImage = data['coverImageUrl'] ?? '';
            
            return GestureDetector(
              onTap: () {
                // TODO: 단일 보드 내 OOTD 목록 보기
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: coverImage.isNotEmpty
                          ? DecorationImage(image: NetworkImage(coverImage), fit: BoxFit.cover)
                          : null,
                    ),
                    child: coverImage.isEmpty ? const Center(child: Icon(Icons.grid_view, color: Colors.grey, size: 40)) : null,
                  ),
                  // 오버레이 및 텍스트
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text('${data['ootdCount'] ?? 0}개', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
