import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_service.dart';
import 'ootd_detail_screen.dart';

class FollowingFeedScreen extends StatefulWidget {
  const FollowingFeedScreen({super.key});

  @override
  State<FollowingFeedScreen> createState() => _FollowingFeedScreenState();
}

class _FollowingFeedScreenState extends State<FollowingFeedScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<String> _followingIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowingIds();
  }

  Future<void> _loadFollowingIds() async {
    setState(() => _isLoading = true);
    final ids = await _firebaseService.getMyFollowingIds();
    setState(() {
      _followingIds = ids;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('피드', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFollowingIds,
        color: Colors.black,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _followingIds.isEmpty
                ? const Center(child: Text('팔로우 중인 사용자가 없습니다.\nDiscover에서 새 친구를 찾아보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                : StreamBuilder<QuerySnapshot>(
                    stream: _firebaseService.getFollowingFeedStream(_followingIds),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.black));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('새로운 게시물이 없습니다.', style: TextStyle(color: Colors.grey)));
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String userName = data['userEmail']?.toString().split('@').first ?? '익명';
                          final int likeCount = data['likeCount'] ?? 0;

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OotdDetailScreen(
                                    docId: doc.id,
                                    data: data,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.black,
                                        child: Icon(Icons.person, size: 18, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  height: 400,
                                  color: Colors.grey[100],
                                  child: CachedNetworkImage(
                                    imageUrl: data['imageUrl'] ?? '',
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.black)),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.favorite_border, size: 24),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.chat_bubble_outline, size: 22),
                                          const Spacer(),
                                          const Icon(Icons.bookmark_border, size: 24),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('좋아요 $likeCount개', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      RichText(
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: const TextStyle(color: Colors.black, fontSize: 13),
                                          children: [
                                            TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const TextSpan(text: '  '),
                                            TextSpan(text: data['description'] ?? ''),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, thickness: 1, color: Colors.black12),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
