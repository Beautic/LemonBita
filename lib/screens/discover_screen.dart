import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import 'ootd_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<QuerySnapshot> _discoverStream;

  @override
  void initState() {
    super.initState();
    _discoverStream = _firebaseService.getDiscoverFeedStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _discoverStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('아직 공유된 OOTD가 없습니다.', style: TextStyle(color: Colors.grey)));
          }

          return MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] ?? '';
              final userName = data['userEmail']?.toString().split('@').first ?? '익명';
              final likeCount = data['likeCount'] ?? 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OotdDetailScreen(docId: docs[index].id, data: data),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[100], height: 200),
                      errorWidget: (context, url, error) => Container(color: Colors.grey[100], height: 200, child: const Icon(Icons.error, color: Colors.grey)),
                    ),
                    // 그라데이션 오버레이 (텍스트 가독성)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 10, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 12, color: Colors.white)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(userName, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          const Icon(Icons.favorite_border, size: 12, color: Colors.white),
                          const SizedBox(width: 2),
                          Text('$likeCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ), // end Stack
               ), // end ClipRRect
              ); // end GestureDetector
            },
          );
        },
      ),
    );
  }
}
