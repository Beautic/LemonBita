import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class ShareFolderScreen extends StatefulWidget {
  final String userId;
  final String folderId;
  final String type; // 'closet' 또는 'item'

  const ShareFolderScreen({
    super.key,
    required this.userId,
    required this.folderId,
    required this.type,
  });

  @override
  State<ShareFolderScreen> createState() => _ShareFolderScreenState();
}

class _ShareFolderScreenState extends State<ShareFolderScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  String? _errorMsg;

  Map<String, dynamic>? _folderData;
  Map<String, dynamic>? _ownerProfile;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadShareData();
  }

  Future<void> _loadShareData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      // 1. 폴더 정보 조회
      final folder = await _firebaseService.getFolderById(widget.folderId, widget.type);
      if (folder == null) {
        throw Exception("존재하지 않거나 삭제된 가방입니다.");
      }

      // 비공개 폴더인 경우 에러 처리
      final bool isShared = folder['isSharedWithFriends'] ?? false;
      final List<dynamic> allowedUids = folder['sharedWithFriendIds'] ?? [];
      
      final currentUid = _firebaseService.currentUserId;
      final isAllowed = isShared || (currentUid != null && (currentUid == folder['userId'] || allowedUids.contains(currentUid)));

      if (!isAllowed) {
        throw Exception("비공개 상태의 가방입니다. 소유자만 공유 링크를 조회할 수 있습니다.");
      }

      _folderData = folder;

      // 2. 소유자 프로필 조회
      final owner = await _firebaseService.getUserProfileDirect(widget.userId);
      _ownerProfile = owner;

      // 3. 아이템 목록 조회
      final list = await _firebaseService.getFolderItemsDirect(widget.folderId, widget.type);
      _items = list;

    } catch (e) {
      _errorMsg = e.toString().replaceAll("Exception:", "").trim();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownerNickname = _ownerProfile?['nickname'] ?? '사용자';
    final folderName = _folderData?['name'] ?? '보관함';

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.ink))
          : _errorMsg != null
              ? _buildErrorView()
              : SafeArea(
                  child: Column(
                    children: [
                      // 상단 쉐도우 바
                      _buildHeader(ownerNickname, folderName),
                      
                      // 메인 인벤토리 슬롯 리스트
                      Expanded(child: _buildInventoryGrid()),

                      // 하단 랜딩 액션 버튼
                      _buildFooter(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(String nickname, String folderName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.ink.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 12, color: AppColors.ink),
                    const SizedBox(width: 4),
                    Text(
                      widget.type == 'closet' ? '옷장 가방 공유' : '아이템 가방 공유',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nickname,
            style: const TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            folderName,
            style: const TextStyle(fontSize: 22, color: AppColors.ink, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            '총 ${_items.length}개의 아이템이 소장되어 있습니다.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: AppColors.muted.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('보관함이 비어 있습니다.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final imageUrl = item['imageUrl'] as String? ?? '';
        final name = item['name'] as String? ?? item['category'] ?? '아이템';
        final isFavorite = item['isFavorite'] == true;

        return GestureDetector(
          onTap: () => _showItemDetailBottomSheet(item),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 이미지 렌더링
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.muted)),
                        )
                      : const Center(child: Icon(Icons.image_not_supported_rounded, color: AppColors.muted)),
                  
                  // 즐겨찾기
                  if (isFavorite)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                        ),
                        child: const Icon(Icons.star_rounded, size: 10, color: AppColors.accent),
                      ),
                    ),
                  
                  // 아래쪽 타이틀 텍스트
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      color: Colors.black.withOpacity(0.6),
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showItemDetailBottomSheet(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl'] as String? ?? '';
    final name = item['name'] as String? ?? item['category'] ?? '아이템';
    final category = item['category'] as String? ?? '';
    final subCategory = item['subCategory'] as String? ?? '';
    final memo = item['memo'] as String? ?? '';
    final brand = item['brand'] as String? ?? item['color'] ?? '';
    final tags = item['tags'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.ground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover)
                            : const Icon(Icons.image, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subCategory.isNotEmpty ? '$category > $subCategory' : category,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                          if (brand.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '브랜드/제조사: $brand',
                              style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (memo.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('메모', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.ground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      memo,
                      style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4),
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    tags,
                    style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('닫기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line, width: 1.2)),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        onPressed: () {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        },
        child: const Text(
          '나만의 아이템 인벤토리 만들기 📦',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_rounded, size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              '조회할 수 없음',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg ?? '알 수 없는 오류가 발생했습니다.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              child: const Text('마이벤토리 홈으로 이동', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
