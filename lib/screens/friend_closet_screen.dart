import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'coordination_canvas_screen.dart';
import 'planned_ootd_detail_screen.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class FriendClosetScreen extends StatefulWidget {
  final Map<String, dynamic> friendData;
  const FriendClosetScreen({super.key, required this.friendData});

  @override
  State<FriendClosetScreen> createState() => _FriendClosetScreenState();
}

class _FriendClosetScreenState extends State<FriendClosetScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedTab = 0; // 0: 의류 목록, 1: 추천한 코디

  @override
  Widget build(BuildContext context) {
    final String friendUid = widget.friendData['uid'];
    final String friendNickname = widget.friendData['nickname'] ?? '친구';

    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        title: Text(
          '$friendNickname님의 인벤토리',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.ink,
      ),
      body: Column(
        children: [
          // 1. 코디 도와주기 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CoordinationCanvasScreen(
                      friendUid: friendUid,
                      friendNickname: friendNickname,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.style, size: 18),
              label: Text('$friendNickname님 코디 도와주기', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.surface,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ),

          // 2. 탭 전환 바 (의류 목록 vs 추천한 코디)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.slot,
                borderRadius: BorderRadius.circular(AppRadius.slot),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      label: '아이템 목록',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      label: '추천한 코디',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. 메인 콘텐츠 분기 렌더링
          Expanded(
            child: _selectedTab == 0
                ? _buildClothesTab(friendUid)
                : _buildSuggestedOutfitsTab(friendUid),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.slot - 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.surface : AppColors.muted,
          ),
        ),
      ),
    );
  }

  // 첫 번째 탭: 친구의 의류 목록 (3열 정사각 슬롯형 그리드)
  Widget _buildClothesTab(String friendUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clothes')
          .where('userId', isEqualTo: friendUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.ink));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              '등록된 아이템이 없습니다.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          );
        }

        final clothes = snapshot.data!.docs;

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: clothes.length,
          itemBuilder: (context, index) {
            final data = clothes[index].data() as Map<String, dynamic>;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.slot),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.all(6),
              child: Center(
                child: Image.network(
                  data['imageUrl'] ?? '',
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.ink));
                  },
                  errorBuilder: (context, url, error) => const Icon(Icons.error_outline_rounded, color: AppColors.muted, size: 20),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 두 번째 탭: 내가 추천한 코디 목록 (2열 4:5 직사각 화보 그리드)
  Widget _buildSuggestedOutfitsTab(String friendUid) {
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('planned_ootds')
          .where('userId', isEqualTo: friendUid)
          .where('suggestedById', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.ink));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 48, color: AppColors.line),
                const SizedBox(height: 12),
                const Text(
                  '아직 추천한 코디가 없습니다.\n첫 제안을 남겨 친구를 도와보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          );
        }

        // 복합 인덱스 우회를 위해 메모리 상에서 최신순 정렬 수행
        final List<QueryDocumentSnapshot> ootds = List.from(snapshot.data!.docs)
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8, // 4:5 매거진 비율 맞춤
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: ootds.length,
          itemBuilder: (context, index) {
            final doc = ootds[index];
            final data = doc.data() as Map<String, dynamic>;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlannedOotdDetailScreen(plannedOotdId: doc.id),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card - 1)),
                        child: Container(
                          color: AppColors.ground,
                          child: Image.network(
                            data['imageUrl'] ?? '',
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink));
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.error_outline_rounded, color: AppColors.muted),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('제안된 코디', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.ink)),
                          if (data['createdAt'] != null)
                            Text(
                              _formatTimestamp(data['createdAt'] as Timestamp),
                              style: AppText.mono.copyWith(fontSize: 9, color: AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year.toString().substring(2)}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
