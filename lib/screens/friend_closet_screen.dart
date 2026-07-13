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
  int _selectedTab = 0; // 0: 의류, 1: 일반 아이템, 2: 추천 코디
  String _selectedClothesFolderId = 'all';
  String _selectedItemsFolderId = 'all';

  @override
  Widget build(BuildContext context) {
    final String friendUid = widget.friendData['uid'];
    final String friendNickname = widget.friendData['nickname'] ?? '친구';

    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        title: Text(
          '$friendNickname님의 쇼룸',
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

          // 2. 탭 전환 바 (의류 vs 일반 아이템 vs 추천 코디)
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
                      label: '의류 👕',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      label: '아이템 📦',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      label: '추천 코디 🎀',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
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
                : _selectedTab == 1
                    ? _buildItemsTab(friendUid)
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

  // 1) 의류 탭 (친구의 공개 폴더 칩 바 + 필터링된 의류 그리드)
  Widget _buildClothesTab(String friendUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('closet_folders')
          .where('userId', isEqualTo: friendUid)
          .snapshots(),
      builder: (context, folderSnapshot) {
        final folderDocs = folderSnapshot.data?.docs ?? [];
        final String myUid = _firebaseService.currentUserId ?? '';
        final publicFolders = folderDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isShared = data['isSharedWithFriends'] ?? false;
          final List<dynamic> allowedUids = data['sharedWithFriendIds'] ?? [];
          return isShared || allowedUids.contains(myUid);
        }).toList();

        final publicFolderIds = publicFolders.map((doc) => doc.id).toSet();
        final privateFolderIds = folderDocs
            .where((doc) => !publicFolderIds.contains(doc.id))
            .map((doc) => doc.id)
            .toSet();

        return Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('전체', style: TextStyle(fontSize: 11)),
                    selected: _selectedClothesFolderId == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _selectedClothesFolderId = 'all');
                    },
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('미분류', style: TextStyle(fontSize: 11)),
                    selected: _selectedClothesFolderId == 'unclassified',
                    onSelected: (val) {
                      if (val) setState(() => _selectedClothesFolderId = 'unclassified');
                    },
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                  ),
                  ...publicFolders.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedClothesFolderId == doc.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(data['name'] ?? '', style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedClothesFolderId = doc.id);
                        },
                        selectedColor: AppColors.ink,
                        backgroundColor: AppColors.surface,
                        showCheckmark: false,
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clothes')
                    .where('userId', isEqualTo: friendUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, clothesSnapshot) {
                  if (clothesSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                  }
                  final docs = clothesSnapshot.data?.docs ?? [];

                  // 비공개 폴더 소속 의류 필터링
                  final filteredClothes = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['isSharedWithFriends'] == false) return false;

                    final List<dynamic> folderIds = data['folderIds'] ?? [];
                    if (folderIds.isNotEmpty && folderIds.every((fid) => privateFolderIds.contains(fid))) {
                      return false;
                    }

                    if (_selectedClothesFolderId == 'unclassified') {
                      return folderIds.isEmpty;
                    } else if (_selectedClothesFolderId != 'all') {
                      return folderIds.contains(_selectedClothesFolderId);
                    }
                    return true;
                  }).toList();

                  if (filteredClothes.isEmpty) {
                    return const Center(
                      child: Text('공유 허용된 의류가 없습니다.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    );
                  }

                  return GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredClothes.length,
                    itemBuilder: (context, index) {
                      final doc = filteredClothes[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Image.network(
                            data['imageUrl'] ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (context, url, error) => const Icon(Icons.error_outline_rounded, color: AppColors.muted, size: 20),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // 2) 일반 아이템 탭 (친구의 공개 아이템 폴더 칩 바 + 필터링된 일반 아이템 그리드)
  Widget _buildItemsTab(String friendUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('item_folders')
          .where('userId', isEqualTo: friendUid)
          .snapshots(),
      builder: (context, folderSnapshot) {
        final folderDocs = folderSnapshot.data?.docs ?? [];
        final String myUid = _firebaseService.currentUserId ?? '';
        final publicFolders = folderDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final isShared = data['isSharedWithFriends'] ?? false;
          final List<dynamic> allowedUids = data['sharedWithFriendIds'] ?? [];
          return isShared || allowedUids.contains(myUid);
        }).toList();

        final publicFolderIds = publicFolders.map((doc) => doc.id).toSet();
        final privateFolderIds = folderDocs
            .where((doc) => !publicFolderIds.contains(doc.id))
            .map((doc) => doc.id)
            .toSet();

        return Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('전체', style: TextStyle(fontSize: 11)),
                    selected: _selectedItemsFolderId == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _selectedItemsFolderId = 'all');
                    },
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('미분류', style: TextStyle(fontSize: 11)),
                    selected: _selectedItemsFolderId == 'unclassified',
                    onSelected: (val) {
                      if (val) setState(() => _selectedItemsFolderId = 'unclassified');
                    },
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.surface,
                    showCheckmark: false,
                  ),
                  ...publicFolders.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedItemsFolderId == doc.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(data['name'] ?? '', style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedItemsFolderId = doc.id);
                        },
                        selectedColor: AppColors.ink,
                        backgroundColor: AppColors.surface,
                        showCheckmark: false,
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('items')
                    .where('userId', isEqualTo: friendUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, itemsSnapshot) {
                  if (itemsSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                  }
                  final docs = itemsSnapshot.data?.docs ?? [];

                  // 비공개 폴더 소속 아이템 필터링
                  final filteredItems = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['isSharedWithFriends'] == false) return false;

                    final List<dynamic> folderIds = data['folderIds'] ?? [];
                    if (folderIds.isNotEmpty && folderIds.every((fid) => privateFolderIds.contains(fid))) {
                      return false;
                    }

                    if (_selectedItemsFolderId == 'unclassified') {
                      return folderIds.isEmpty;
                    } else if (_selectedItemsFolderId != 'all') {
                      return folderIds.contains(_selectedItemsFolderId);
                    }
                    return true;
                  }).toList();

                  if (filteredItems.isEmpty) {
                    return const Center(
                      child: Text('공유 허용된 아이템이 없습니다.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    );
                  }

                  return GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final doc = filteredItems[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(color: AppColors.line),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Image.network(
                            data['imageUrl'] ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (context, url, error) => const Icon(Icons.error_outline_rounded, color: AppColors.muted, size: 20),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // 3) 추천 코디 탭 (2열 4:5 직사각 화보 그리드)
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 48, color: AppColors.line),
                SizedBox(height: 12),
                Text(
                  '아직 추천한 코디가 없습니다.\n첫 제안을 남겨 친구를 도와보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          );
        }

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
            childAspectRatio: 0.8,
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
                        child: data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty
                            ? Image.network(data['imageUrl'], fit: BoxFit.cover)
                            : const Center(child: Icon(Icons.style_outlined, size: 36, color: AppColors.line)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        data['title'] ?? '추천 코디',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}
