import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import 'friends_screen.dart';
import 'clothing_detail_screen.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _editProfile(Map<String, dynamic> currentData) async {
    final nicknameController = TextEditingController(text: currentData['nickname'] ?? '');
    Uint8List? newImageBytes;
    String currentImageUrl = currentData['profileImageUrl'] ?? '';
    bool isSaving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('프로필 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 400,
                          maxHeight: 400,
                          imageQuality: 70,
                        );
                        if (image != null) {
                          final bytes = await image.readAsBytes();
                          setModalState(() {
                            newImageBytes = bytes;
                          });
                        }
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.slot,
                            backgroundImage: newImageBytes != null
                                ? MemoryImage(newImageBytes!)
                                : (currentImageUrl.isNotEmpty
                                    ? NetworkImage(currentImageUrl)
                                    : null) as ImageProvider?,
                            child: (newImageBytes == null && currentImageUrl.isEmpty)
                                ? const Icon(Icons.person, size: 40, color: AppColors.muted)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.ink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: AppColors.surface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nicknameController,
                    maxLength: 10,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: '닉네임',
                      labelStyle: const TextStyle(color: AppColors.muted),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppColors.ink),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  isSaving
                      ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
                      : ElevatedButton(
                          onPressed: () async {
                            final newName = nicknameController.text.trim();
                            if (newName.isEmpty) return;

                            setModalState(() => isSaving = true);
                            try {
                              await _firebaseService.updateUserProfile(
                                nickname: newName,
                                profileImageBytes: newImageBytes,
                                existingImageUrl: currentImageUrl,
                              );
                              if (mounted) Navigator.pop(context);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
                            } finally {
                              setModalState(() => isSaving = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.surface,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                          ),
                          child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        title: Text(
          'MYVENTORY',
          style: AppText.mono.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 16,
            color: AppColors.ink,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.ground,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.ink, size: 20),
            onPressed: () async {
              await _firebaseService.logout();
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firebaseService.getUserProfileStream(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.ink));
          }

          Map<String, dynamic> userData = {};
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            userData = userSnapshot.data!.data() as Map<String, dynamic>;
          }

          final nickname = userData['nickname'] ?? '이름 없음';
          final profileImageUrl = userData['profileImageUrl'] ?? '';
          final email = _firebaseService.currentUser?.email ?? '';

          return StreamBuilder<QuerySnapshot>(
            stream: _firebaseService.getOOTDStream(),
            builder: (context, ootdSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firebaseService.getClothesStream(),
                builder: (context, clothesSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firebaseService.getItemsStream(),
                    builder: (context, itemsSnapshot) {
                      if (clothesSnapshot.connectionState == ConnectionState.waiting ||
                          ootdSnapshot.connectionState == ConnectionState.waiting ||
                          itemsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.ink));
                      }

                      final clothes = clothesSnapshot.data?.docs ?? [];
                      final ootds = ootdSnapshot.data?.docs ?? [];
                      final items = itemsSnapshot.data?.docs ?? [];

                      // OOTD 착용 횟수
                      Map<String, int> tagCounts = {};
                      for (var doc in ootds) {
                        final data = doc.data() as Map<String, dynamic>;
                        List<dynamic> taggedIds = data['taggedClothesIds'] ?? [];
                        if (taggedIds.isEmpty && data['taggedClothes'] != null) {
                          taggedIds = (data['taggedClothes'] as List).map((e) => e['id']).toList();
                        }
                        for (var id in taggedIds) {
                          tagCounts[id.toString()] = (tagCounts[id.toString()] ?? 0) + 1;
                        }
                      }

                      // 6개월 기준 잠자고 있는 옷
                      final List<Map<String, dynamic>> scoredClothes = clothes.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return {
                          'docId': doc.id,
                          'data': data,
                          'tagCount': tagCounts[doc.id] ?? 0,
                        };
                      }).toList();

                      final unusedClothes = scoredClothes.where((item) => item['tagCount'] == 0).toList();

                      // 일반 아이템 플레이/사용 횟수 합산
                      int itemsPlayCount = 0;
                      for (var doc in items) {
                        final data = doc.data() as Map<String, dynamic>;
                        itemsPlayCount += (data['usageCount'] as num? ?? 0).toInt();
                      }

                      // 카테고리 비율 계산
                      Map<String, int> categoryCounts = {};
                      for (var doc in clothes) {
                        final data = doc.data() as Map<String, dynamic>;
                        final category = data['category'] ?? '기타';
                        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
                      }

                      final sortedCategories = categoryCounts.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      // 최애템 TOP 3
                      final favoriteClothes = List<Map<String, dynamic>>.from(scoredClothes)
                        ..sort((a, b) => (b['tagCount'] as int).compareTo(a['tagCount'] as int));
                      final top3Clothes = favoriteClothes.where((item) => item['tagCount'] > 0).take(3).toList();

                      return StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _firebaseService.getClosetFoldersStream(),
                        builder: (context, closetFolderSnapshot) {
                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: _firebaseService.getItemFoldersStream(),
                            builder: (context, itemFolderSnapshot) {
                              final closetFoldersCount = closetFolderSnapshot.data?.length ?? 0;
                              final itemFoldersCount = itemFolderSnapshot.data?.length ?? 0;
                              final foldersCount = closetFoldersCount + itemFoldersCount;

                              return SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // 1. 프로필 요약 헤더 (작게, 1줄)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(AppRadius.card),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundColor: AppColors.slot,
                                            backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                                            child: profileImageUrl.isEmpty ? const Icon(Icons.person, size: 26, color: AppColors.muted) : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(nickname, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                                const SizedBox(height: 2),
                                                Text(email, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                              ],
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _editProfile(userData),
                                            icon: const Icon(Icons.edit, size: 12, color: AppColors.ink),
                                            label: const Text('수정', style: TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. 통계 4칸
                                    Row(
                                      children: [
                                        Expanded(child: _buildStatCell('CLOTHES', '${clothes.length}', isAccent: false)),
                                        const SizedBox(width: 6),
                                        Expanded(child: _buildStatCell('ITEMS', '${items.length}', isAccent: false)),
                                        const SizedBox(width: 6),
                                        Expanded(child: _buildStatCell('FOLDERS', '$foldersCount', isAccent: false)),
                                        const SizedBox(width: 6),
                                        Expanded(child: _buildStatCell('WORN&PLAY', '${ootds.length + itemsPlayCount}', isAccent: true)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                            // 3. 카테고리 분포 (막대 차트)
                            if (clothes.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('카테고리 비율 📊', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                    const SizedBox(height: 12),
                                    ...sortedCategories.map((entry) {
                                      final double rate = entry.value / clothes.length;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(entry.key, style: const TextStyle(fontSize: 12, color: AppColors.ink)),
                                                Text(
                                                  '${entry.value}개 (${(rate * 100).toStringAsFixed(0)}%)',
                                                  style: AppText.mono.copyWith(fontSize: 11, color: AppColors.muted),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: rate,
                                                minHeight: 5,
                                                backgroundColor: AppColors.slot,
                                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 4. 최애템 TOP 3
                            if (top3Clothes.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('가장 많이 입은 TOP 3 🔥', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                    const SizedBox(height: 12),
                                    ...top3Clothes.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final item = entry.value;
                                      final data = item['data'] as Map<String, dynamic>;
                                      final count = item['tagCount'];

                                      String color = data['color'] ?? '';
                                      String pattern = data['pattern'] ?? '';
                                      String title = '$color $pattern'.trim();
                                      if (title.isEmpty) title = data['brand'] ?? '';
                                      if (title.isEmpty) title = data['category'] ?? '아이템';

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(AppRadius.slot),
                                          child: Image.network(data['imageUrl'] ?? '', width: 36, height: 36, fit: BoxFit.cover),
                                        ),
                                        title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.ink)),
                                        subtitle: Text(data['category'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                        trailing: Text(
                                          '${idx + 1}위 · $count회',
                                          style: AppText.mono.copyWith(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 5. 잠자고 있는 아이템 붉은 배너
                            if (unusedClothes.isNotEmpty)
                              GestureDetector(
                                onTap: () => _showUnusedClothesDialog(unusedClothes),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(AppRadius.card),
                                    border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            '아직 한 번도 안 입은 아이템이 ${unusedClothes.length}개 있습니다.',
                                            style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // 6. 하단 메뉴 목록
                            ListTile(
                              title: const Text('내 친구 관리', style: TextStyle(fontSize: 13, color: AppColors.ink)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.muted),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
                              },
                            ),
                            const Divider(height: 1, color: AppColors.line),
                          ],
                        ),
                      );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCell(String title, String value, {required bool isAccent}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.slot),
        border: Border.all(color: isAccent ? AppColors.accent : AppColors.line, width: isAccent ? 1.5 : 1.0),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 9, color: isAccent ? AppColors.accent : AppColors.muted, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.mono.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isAccent ? AppColors.accent : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  void _showUnusedClothesDialog(List<Map<String, dynamic>> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '잠자는 아이템 목록 💤',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final data = item['data'] as Map<String, dynamic>;
                    final String docId = item['docId'];

                    String color = data['color'] ?? '';
                    String pattern = data['pattern'] ?? '';
                    String title = '$color $pattern'.trim();
                    if (title.isEmpty) title = data['brand'] ?? '';
                    if (title.isEmpty) title = data['category'] ?? '아이템';

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClothingDetailScreen(docId: docId, item: data),
                          ),
                        );
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.slot,
                                  borderRadius: BorderRadius.circular(AppRadius.slot),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Center(
                                  child: Image.network(
                                    data['imageUrl'] ?? '',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
