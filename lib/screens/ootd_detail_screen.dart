import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../services/firebase_service.dart';

class OotdDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const OotdDetailScreen({super.key, required this.docId, required this.data});

  @override
  State<OotdDetailScreen> createState() => _OotdDetailScreenState();
}

class _OotdDetailScreenState extends State<OotdDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkLikeState();
    _checkSaveState();
  }

  void _checkSaveState() {
    if (_firebaseService.currentUserId == null) return;
    FirebaseFirestore.instance
        .collection('users')
        .doc(_firebaseService.currentUserId)
        .collection('savedOotds')
        .doc(widget.docId)
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _isSaved = doc.exists;
        });
      }
    });
  }

  void _checkLikeState() {
    if (_firebaseService.currentUserId == null) return;
    FirebaseFirestore.instance
        .collection('ootds')
        .doc(widget.docId)
        .collection('likes')
        .doc(_firebaseService.currentUserId)
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _isLiked = doc.exists;
        });
      }
    });
  }

  Future<void> _handleLike() async {
    try {
      await _firebaseService.toggleLike(widget.docId, _isLiked);
      // NOTE: Cloud Functions가 배포되지 않은 경우 카운트가 즉시 오르지 않을 수 있습니다.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('에러: $e')));
    }
  }

  void _handleShare() {
    final String url = "https://digital-closet-32c43.web.app/ootd/${widget.docId}"; // 예시 URL
    Share.share('이 멋진 OOTD를 확인해보세요! $url');
  }

  void _showSaveBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('어느 보드에 저장할까요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.add, color: Colors.white)),
                  title: const Text('새 보드 만들기', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateCollectionDialog();
                  },
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firebaseService.getCollectionsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text('생성된 보드가 없습니다.', style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                image: (data['coverImageUrl'] ?? '').isNotEmpty 
                                    ? DecorationImage(image: NetworkImage(data['coverImageUrl']), fit: BoxFit.cover) 
                                    : null,
                              ),
                              child: (data['coverImageUrl'] ?? '').isEmpty ? const Icon(Icons.grid_view) : null,
                            ),
                            title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text('저장됨 ${data['ootdCount'] ?? 0}개'),
                            onTap: () async {
                              Navigator.pop(context);
                              await _firebaseService.toggleSave(widget.docId, false, collectionId: docs[index].id);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${data['title']} 보드에 저장되었습니다.')));
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateCollectionDialog() {
    final TextEditingController _controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('새 보드 만들기'),
          content: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: '보드 이름 (예: 봄 코디 모음)'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () async {
                if (_controller.text.trim().isNotEmpty) {
                  final newCollectionId = await _firebaseService.createCollection(_controller.text.trim());
                  await _firebaseService.toggleSave(widget.docId, false, collectionId: newCollectionId);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_controller.text.trim()} 보드에 저장되었습니다.')));
                }
              },
              child: const Text('저장', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.data;
    
    // Timestamp 변환
    String dateStr = '';
    if (item['createdAt'] != null) {
      final dt = (item['createdAt'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy년 MM월 dd일').format(dt);
    }

    final String userName = item['userEmail']?.toString().split('@').first ?? '익명';
    List<dynamic> taggedClothes = item['taggedClothes'] ?? [];
    final int likeCount = item['likeCount'] ?? 0;
    final int commentCount = item['commentCount'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('OOTD', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 헤더 (유저 정보 + 날짜)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.person, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  if (item['userId'] != null && item['userId'] != _firebaseService.currentUserId)
                    StreamBuilder<bool>(
                      stream: _firebaseService.isFollowingStream(item['userId']),
                      builder: (context, snapshot) {
                        final isFollowing = snapshot.data ?? false;
                        return OutlinedButton(
                          onPressed: () async {
                            await _firebaseService.toggleFollow(item['userId'], isFollowing);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(60, 30),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: isFollowing ? Colors.white : Colors.black,
                            side: BorderSide(color: isFollowing ? Colors.grey : Colors.black),
                          ),
                          child: Text(
                            isFollowing ? '팔로잉' : '팔로우',
                            style: TextStyle(
                              color: isFollowing ? Colors.black : Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
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
              child: CachedNetworkImage(
                imageUrl: item['imageUrl'] ?? '',
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.black)),
                errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),

            // 3. 소셜 액션 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 28,
                      color: _isLiked ? const Color(0xFFED4956) : Colors.black,
                    ),
                    onPressed: _handleLike,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 26),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_outlined, size: 26),
                    onPressed: _handleShare,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border, 
                      size: 28,
                      color: _isSaved ? Colors.black : Colors.black,
                    ),
                    onPressed: () async {
                      if (_isSaved) {
                        await _firebaseService.toggleSave(widget.docId, true);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장 취소되었습니다.')));
                      } else {
                        _showSaveBottomSheet();
                      }
                    },
                  ),
                ],
              ),
            ),
            
            // 4. 좋아요 수
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('좋아요 $likeCount개', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),

            // 5. 코멘트 영역
            if ((item['description'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: '  '),
                      TextSpan(text: item['description']),
                    ],
                  ),
                ),
              ),
              
            // 6. 댓글 수 
            if (commentCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Text('댓글 $commentCount개 모두 보기', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ),

            const SizedBox(height: 16),

            // 7. 태그된 옷 영역
            if (taggedClothes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.sell, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('이 OOTD에 입은 옷', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}
