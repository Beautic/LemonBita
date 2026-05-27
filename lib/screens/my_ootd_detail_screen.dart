import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../widgets/ootd_interaction_bar.dart';
import 'search_clothes_screen.dart';

class MyOotdDetailScreen extends StatefulWidget {
  final String ootdId;

  const MyOotdDetailScreen({super.key, required this.ootdId});

  @override
  State<MyOotdDetailScreen> createState() => _MyOotdDetailScreenState();
}

class _MyOotdDetailScreenState extends State<MyOotdDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('OOTD 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('이 OOTD를 삭제하시겠습니까?\n삭제 후에는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firebaseService.deleteOOTDData(widget.ootdId);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 기록', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deletePost,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('ootds').doc(widget.ootdId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text('삭제되었거나 존재하지 않는 게시글입니다.'));
          }

          final item = snapshot.data!.data() as Map<String, dynamic>;
          
          String dateStr = '';
          if (item['createdAt'] != null) {
            final dt = (item['createdAt'] as Timestamp).toDate();
            dateStr = DateFormat('yyyy년 MM월 dd일').format(dt);
          }

          List<dynamic> taggedClothes = item['taggedClothes'] ?? [];

          return SingleChildScrollView(
            child: Column(
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
                      const Text(
                        'My Daily Look',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month, size: 20, color: Colors.black54),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final initialDate = item['createdAt'] != null ? (item['createdAt'] as Timestamp).toDate() : DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.black,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && !DateUtils.isSameDay(picked, initialDate)) {
                            await _firebaseService.updateOOTDDate(widget.ootdId, picked);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('날짜가 수정되었습니다.')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: Colors.black54),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final initialIds = taggedClothes.map((cloth) => cloth['id'] as String).toSet();
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchClothesScreen(
                                isSelectionMode: true,
                                initialSelectedIds: initialIds,
                              ),
                            ),
                          );

                          if (result != null && result is List<Map<String, dynamic>>) {
                            await _firebaseService.updateOOTDTags(widget.ootdId, result);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('태그가 수정되었습니다.')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 2. 이미지
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width,
                  color: Colors.grey[100],
                  child: Image.network(
                    item['imageUrl'] ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                  ),
                ),

                // 3. 소셜 인터랙션 영역 (좋아요, 댓글)
                OotdInteractionBar(
                  ootdId: widget.ootdId,
                  ownerId: item['userId'] ?? '',
                  likedBy: item['likedBy'] ?? [],
                  commentCount: item['commentCount'] ?? 0,
                  firebaseService: _firebaseService,
                  onLikeToggled: (newLikedBy) {}, // No need to manually update state, StreamBuilder will refresh
                ),

                // 4. 코멘트 영역
                if ((item['description'] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      item['description'],
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),

                // 5. 태그된 옷 영역
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
            ),
          );
        },
      ),
    );
  }
}
