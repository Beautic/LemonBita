import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class ItemDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> item;

  const ItemDetailScreen({
    super.key,
    required this.docId,
    required this.item,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late Map<String, dynamic> _currentItem;
  late Stream<QuerySnapshot> _diaryStream;
  late Stream<DocumentSnapshot> _itemDocStream;

  @override
  void initState() {
    super.initState();
    _currentItem = Map<String, dynamic>.from(widget.item);
    _diaryStream = _firebaseService.getUsageDiaryStream(widget.docId);
    _itemDocStream = FirebaseFirestore.instance.collection('items').doc(widget.docId).snapshots();
  }

  // 사용 기록 다이얼로그 띄우기
  void _showAddUsageRecordDialog() {
    final TextEditingController commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: AppColors.ink),
              SizedBox(width: 8),
              Text('사용/플레이 일지 쓰기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: TextField(
            controller: commentController,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '메모를 적어주세요 (예: 친구와 4인플, 가볍게 뿌림)',
              hintStyle: TextStyle(fontSize: 12),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.ink)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              onPressed: () async {
                final comment = commentController.text.trim();
                final memo = comment.isEmpty ? '사용함' : comment;
                await _firebaseService.addUsageRecord(widget.docId, memo);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('기록 완료', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 삭제 처리
  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('아이템 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('정말로 이 아이템을 삭제하시겠습니까?\n모든 사용 기록 일지도 영구 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              await _firebaseService.deleteItemData(widget.docId);
              if (context.mounted) {
                Navigator.pop(context); // 팝업 닫기
                Navigator.pop(context); // 상세 페이지 닫기
              }
            },
            child: const Text('삭제하기', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // 폴더 변경 다이얼로그
  void _showFolderAssignDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firebaseService.getItemFoldersStream(),
          builder: (context, snapshot) {
            final folders = snapshot.data ?? [];

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
              title: const Text('이동할 가방 선택', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: folders.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('생성된 아이템용 가방이 없습니다.\n가방을 먼저 만들어보세요.', textAlign: TextAlign.center),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final folder = folders[index];
                          return ListTile(
                            leading: const Icon(Icons.folder, color: AppColors.muted),
                            title: Text(folder['name'] ?? ''),
                            onTap: () async {
                              await _firebaseService.updateItemData(
                                docId: widget.docId,
                                updatedData: {
                                  'folderIds': [folder['id']],
                                  'folderId': folder['id'],
                                },
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: AppColors.muted)),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _itemDocStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          _currentItem = snapshot.data!.data() as Map<String, dynamic>;
        }

        final bool isFavorite = _currentItem['isFavorite'] ?? false;
        final int usageCount = (_currentItem['usageCount'] as num?)?.toInt() ?? 0;
        final int price = (_currentItem['price'] as num?)?.toInt() ?? 0;
        final String priceStr = price > 0 ? NumberFormat('#,###').format(price) : '정보 없음';

        return Scaffold(
          backgroundColor: AppColors.ground,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(_currentItem['name'] ?? '아이템 상세', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            actions: [
              IconButton(
                icon: Icon(isFavorite ? Icons.star_rounded : Icons.star_outline_rounded, color: isFavorite ? AppColors.accent : AppColors.muted),
                onPressed: () async {
                  await _firebaseService.updateItemData(
                    docId: widget.docId,
                    updatedData: {'isFavorite': !isFavorite},
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.folder_open_rounded, color: AppColors.ink),
                onPressed: _showFolderAssignDialog,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accent),
                onPressed: _showDeleteConfirmDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이미지 뷰 영역
                      Container(
                        width: double.infinity,
                        height: 300,
                        color: AppColors.surface,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Image.network(
                              _currentItem['imageUrl'] ?? '',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.inventory_2_outlined, size: 72, color: AppColors.line),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 스펙 카드 영역
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Card(
                          color: AppColors.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            side: const BorderSide(color: AppColors.line, width: 0.8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSpecRow('카테고리', _currentItem['category'] ?? '미분류'),
                                const Divider(height: 20, color: AppColors.line),
                                _buildSpecRow('제조사 / 브랜드', (_currentItem['brand'] ?? '').isNotEmpty ? _currentItem['brand'] : '정보 없음'),
                                const Divider(height: 20, color: AppColors.line),
                                _buildSpecRow('소장 시작일', (_currentItem['acquiredDate'] ?? '').isNotEmpty ? _currentItem['acquiredDate'] : '정보 없음'),
                                const Divider(height: 20, color: AppColors.line),
                                _buildSpecRow('가격 / 가치', price > 0 ? '$priceStr 원' : '정보 없음'),
                                const Divider(height: 20, color: AppColors.line),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('메모', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    Text(
                                      (_currentItem['memo'] ?? '').isNotEmpty ? _currentItem['memo'] : '등록된 메모가 없습니다.',
                                      style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 사용 기록 타임라인 헤더
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history_toggle_off_rounded, size: 20, color: AppColors.ink),
                                const SizedBox(width: 6),
                                const Text('사용 / 플레이 일지', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.slot, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    '$usageCount회',
                                    style: AppText.mono.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 0,
                              ),
                              onPressed: _showAddUsageRecordDialog,
                              icon: const Icon(Icons.add, size: 14, color: Colors.white),
                              label: const Text('기록 추가', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 사용 기록 타임라인 리스트
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _diaryStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: const Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.edit_note_outlined, size: 36, color: AppColors.line),
                                      SizedBox(height: 8),
                                      Text('아직 기록된 일지가 없습니다.\n첫 사용 이력을 적어보세요!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final Timestamp? timestamp = data['usedAt'] as Timestamp?;
                                String dateStr = '날짜 정보 없음';
                                if (timestamp != null) {
                                  final dt = timestamp.toDate();
                                  dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.button),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.muted, size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['memo'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                            const SizedBox(height: 4),
                                            Text(dateStr, style: AppText.mono.copyWith(fontSize: 10, color: AppColors.muted)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
