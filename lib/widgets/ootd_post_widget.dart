import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import 'ootd_interaction_bar.dart';

class OotdPostWidget extends StatefulWidget {
  final String collectionName;
  final String ootdId;
  final Map<String, dynamic> data;
  final FirebaseService firebaseService;

  const OotdPostWidget({
    super.key,
    this.collectionName = 'ootds',
    required this.ootdId,
    required this.data,
    required this.firebaseService,
  });

  @override
  State<OotdPostWidget> createState() => _OotdPostWidgetState();
}

class _OotdPostWidgetState extends State<OotdPostWidget> {
  late List<dynamic> _likedBy;
  late int _commentCount;

  @override
  void initState() {
    super.initState();
    _likedBy = List.from(widget.data['likedBy'] ?? []);
    _commentCount = widget.data['commentCount'] ?? 0;
  }

  @override
  void didUpdateWidget(covariant OotdPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _likedBy = List.from(widget.data['likedBy'] ?? []);
      _commentCount = widget.data['commentCount'] ?? 0;
    }
  }

  Future<void> _toggleLike() async {
    final myUid = widget.firebaseService.currentUserId;
    if (myUid == null) return;

    final ownerId = widget.data['userId'] ?? '';
    final isLiked = _likedBy.contains(myUid);
    
    // Optimistic update
    setState(() {
      if (isLiked) {
        _likedBy.remove(myUid);
      } else {
        _likedBy.add(myUid);
      }
    });

    try {
      await widget.firebaseService.toggleOotdLike(widget.ootdId, ownerId, isLiked);
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isLiked) {
            _likedBy.add(myUid);
          } else {
            _likedBy.remove(myUid);
          }
        });
      }
    }
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CommentsSheet(
          ootdId: widget.ootdId,
          ownerId: widget.data['userId'] ?? '',
          firebaseService: widget.firebaseService,
        ),
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

  @override
  Widget build(BuildContext context) {
    final ownerId = widget.data['userId'] ?? '';
    final imageUrl = widget.data['imageUrl'] ?? '';
    final description = widget.data['description'] ?? '';
    final createdAt = widget.data['createdAt'];
    
    final myUid = widget.firebaseService.currentUserId;
    final isLiked = myUid != null && _likedBy.contains(myUid);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(ownerId).get(),
      builder: (context, userSnapshot) {
        String nickname = '사용자';
        String? profileUrl;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          nickname = userData['nickname'] ?? '사용자';
          profileUrl = userData['profileImageUrl'];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: profileUrl?.isNotEmpty == true ? NetworkImage(profileUrl!) : null,
                child: profileUrl?.isEmpty == true ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
              title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_formatTimestamp(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            // Image
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: MediaQuery.of(context).size.width,
              ),
            // Actions
            OotdInteractionBar(
              collectionName: widget.collectionName,
              ootdId: widget.ootdId,
              ownerId: ownerId,
              likedBy: _likedBy,
              commentCount: _commentCount,
              firebaseService: widget.firebaseService,
              onLikeToggled: (newLikedBy) {
                setState(() {
                  _likedBy = List.from(newLikedBy);
                });
              },
            ),
            // Description
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
  }
}

class CommentsSheet extends StatefulWidget {
  final String collectionName;
  final String ootdId;
  final String ownerId;
  final FirebaseService firebaseService;

  const CommentsSheet({
    super.key,
    this.collectionName = 'ootds',
    required this.ootdId,
    required this.ownerId,
    required this.firebaseService,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _replyingToId;
  String? _replyingToNickname;

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parentId = _replyingToId;
    _controller.clear();
    setState(() {
      _replyingToId = null;
      _replyingToNickname = null;
    });

    await widget.firebaseService.addComment(widget.collectionName, widget.ootdId, widget.ownerId, text, parentId: parentId);
  }

  void _startReply(String commentId, String nickname) {
    setState(() {
      _replyingToId = commentId;
      _replyingToNickname = nickname;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToNickname = null;
    });
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
              stream: widget.firebaseService.getCommentsStream(widget.collectionName, widget.ootdId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.black));
                final allComments = snapshot.data!.docs;
                if (allComments.isEmpty) return const Center(child: Text('아직 댓글이 없습니다.'));

                // Group comments by parentId
                final rootComments = <DocumentSnapshot>[];
                final repliesMap = <String, List<DocumentSnapshot>>{};

                for (var doc in allComments) {
                  final data = doc.data() as Map<String, dynamic>;
                  final parentId = data['parentId'];
                  if (parentId == null) {
                    rootComments.add(doc);
                  } else {
                    repliesMap[parentId] ??= [];
                    repliesMap[parentId]!.add(doc);
                  }
                }

                return ListView.builder(
                  itemCount: rootComments.length,
                  itemBuilder: (context, index) {
                    final rootDoc = rootComments[index];
                    final rootData = rootDoc.data() as Map<String, dynamic>;
                    final rootId = rootDoc.id;
                    final rootNickname = rootData['nickname'] ?? '익명';
                    
                    final replies = repliesMap[rootId] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCommentTile(rootId, rootData, false),
                        if (replies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 40.0),
                            child: Column(
                              children: replies.map((replyDoc) {
                                return _buildCommentTile(replyDoc.id, replyDoc.data() as Map<String, dynamic>, true);
                              }).toList(),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),
          if (_replyingToNickname != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
              child: Row(
                children: [
                  Text('$_replyingToNickname님에게 답글 남기는 중...', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  const Spacer(),
                  InkWell(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: _replyingToNickname != null ? '답글 달기...' : '댓글 달기...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: _submitComment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(String id, Map<String, dynamic> data, bool isReply) {
    final nickname = data['nickname'] ?? '익명';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundImage: data['profileImageUrl']?.isNotEmpty == true ? NetworkImage(data['profileImageUrl']) : null,
            child: data['profileImageUrl']?.isEmpty == true ? Icon(Icons.person, size: isReply ? 16 : 20, color: Colors.grey) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nickname, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(data['text'] ?? '', style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                if (!isReply)
                  InkWell(
                    onTap: () => _startReply(id, nickname),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Text('답글 달기', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
