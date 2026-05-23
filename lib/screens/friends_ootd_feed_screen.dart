import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class FriendsOotdFeedScreen extends StatefulWidget {
  const FriendsOotdFeedScreen({super.key});

  @override
  State<FriendsOotdFeedScreen> createState() => _FriendsOotdFeedScreenState();
}

class _FriendsOotdFeedScreenState extends State<FriendsOotdFeedScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<QueryDocumentSnapshot> _feed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _firebaseService.getFriendsOotdFeed();
      if (mounted) {
        setState(() {
          _feed = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike(String ootdId, String ownerId, List<dynamic> likedBy) async {
    final myUid = _firebaseService.currentUserId;
    if (myUid == null) return;

    final isLiked = likedBy.contains(myUid);
    // Optimistic UI update
    setState(() {
      if (isLiked) {
        likedBy.remove(myUid);
      } else {
        likedBy.add(myUid);
      }
    });

    try {
      await _firebaseService.toggleOotdLike(ootdId, ownerId, isLiked);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isLiked) {
            likedBy.add(myUid);
          } else {
            likedBy.remove(myUid);
          }
        });
      }
    }
  }

  void _showCommentsSheet(String ootdId, String ownerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CommentsSheet(ootdId: ootdId, ownerId: ownerId, firebaseService: _firebaseService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (_feed.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFeed,
        color: Colors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('아직 친구들의 OOTD가 없습니다.', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: Colors.black,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _feed.length,
        itemBuilder: (context, index) {
          final doc = _feed[index];
          final data = doc.data() as Map<String, dynamic>;
          final ootdId = doc.id;
          final ownerId = data['userId'] ?? '';
          final imageUrl = data['imageUrl'] ?? '';
          final description = data['description'] ?? '';
          final createdAt = data['createdAt'];
          final List<dynamic> likedBy = data['likedBy'] ?? [];
          final myUid = _firebaseService.currentUserId;
          final isLiked = myUid != null && likedBy.contains(myUid);

          // 여기서 실제로는 친구의 프로필 이미지와 닉네임을 불러와야 하지만, OOTD 문서에 없다면 fetch가 필요함.
          // 단순화를 위해 FutureBuilder로 닉네임 가져오기.
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
            builder: (context, userSnapshot) {
              String nickname = '친구';
              String? profileUrl;
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                nickname = userData['nickname'] ?? '친구';
                profileUrl = userData['profileImageUrl'];
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 헤더
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      backgroundImage: profileUrl?.isNotEmpty == true ? NetworkImage(profileUrl!) : null,
                      child: profileUrl?.isEmpty == true ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                    title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_formatTimestamp(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ),
                  // 이미지
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: MediaQuery.of(context).size.width, // 1:1 비율
                    ),
                  // 액션 바
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.black),
                          onPressed: () => _toggleLike(ootdId, ownerId, likedBy),
                        ),
                        IconButton(
                          icon: const Icon(Icons.mode_comment_outlined, color: Colors.black),
                          onPressed: () => _showCommentsSheet(ootdId, ownerId),
                        ),
                        const Spacer(),
                        if (likedBy.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Text('좋아요 ${likedBy.length}개', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  // 본문
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black, fontSize: 14),
                          children: [
                            TextSpan(text: '$nickname ', style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: description),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy년 M월 d일').format(timestamp.toDate());
    }
    return '';
  }
}

class _CommentsSheet extends StatefulWidget {
  final String ootdId;
  final String ownerId;
  final FirebaseService firebaseService;

  const _CommentsSheet({required this.ootdId, required this.ownerId, required this.firebaseService});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    await widget.firebaseService.addOotdComment(widget.ootdId, widget.ownerId, text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('댓글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firebaseService.getOotdCommentsStream(widget.ootdId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!.docs;
                if (comments.isEmpty) return const Center(child: Text('아직 댓글이 없습니다.'));

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage: data['profileImageUrl']?.isNotEmpty == true ? NetworkImage(data['profileImageUrl']) : null,
                      ),
                      title: Text(data['nickname'] ?? '익명', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(data['text'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: '댓글 달기...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: _submitComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
