import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'upload_item_screen.dart';
import 'item_detail_screen.dart';

class ItemScreen extends StatefulWidget {
  const ItemScreen({super.key});

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedCategory = '전체';
  String _selectedFolderId = 'all';

  // 다중 선택 편집 모드 관련 변수
  bool _isEditMode = false;
  final Set<String> _selectedItemIds = {};

  final List<String> _categories = ['전체', '보드게임', '향수', '피규어', '도서', '전자기기', '기타'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          '아이템 보관함 📦',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          if (_isEditMode) ...[
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = false;
                  _selectedItemIds.clear();
                });
              },
              child: const Text('취소', style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.folder_open_rounded, color: AppColors.ink),
              onPressed: _selectedItemIds.isEmpty ? null : _showBulkFolderAssignDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.accent),
              onPressed: _selectedItemIds.isEmpty ? null : _showBulkDeleteDialog,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded, color: AppColors.ink),
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          // 1. 카테고리 필터 칩 바
          _buildCategoryBar(),
          // 2. 폴더 바 (아이템 가방)
          _buildFolderBar(),
          // 3. 아이템 그리드 영역
          Expanded(child: _buildItemGrid()),
        ],
      ),
    );
  }

  // 카테고리 바 빌더
  Widget _buildCategoryBar() {
    return Container(
      height: 48,
      color: AppColors.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : AppColors.muted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = cat;
                  });
                }
              },
              selectedColor: AppColors.ink,
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
                side: BorderSide(
                  color: isSelected ? AppColors.ink : AppColors.line,
                  width: 1,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  // 폴더 바 빌더
  Widget _buildFolderBar() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firebaseService.getItemFoldersStream(),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? [];

        return Container(
          height: 62,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFolderButton('all', '전체 가방', _selectedFolderId == 'all'),
              const SizedBox(width: 8),
              _buildFolderButton('unclassified', '미분류', _selectedFolderId == 'unclassified'),
              const SizedBox(width: 8),
              ...folders.map((folder) {
                final isShared = folder['isSharedWithFriends'] ?? false;
                final sharedFriendIds = List<String>.from(folder['sharedWithFriendIds'] ?? []);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildFolderButton(
                    folder['id'] ?? '',
                    folder['name'] ?? '',
                    _selectedFolderId == folder['id'],
                    isShared: isShared,
                    sharedWithFriendIds: sharedFriendIds,
                  ),
                );
              }),
              _buildAddFolderButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolderButton(String id, String label, bool isSelected, {bool isShared = false, List<String> sharedWithFriendIds = const []}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFolderId = id;
          });
        },
        onLongPress: () {
          if (id != 'all' && id != 'unclassified') {
            _showFolderManageDialog(id, label, isShared, sharedWithFriendIds);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.slot : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: isSelected ? AppColors.ink : AppColors.line, width: isSelected ? 1.2 : 0.8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                id == 'all'
                    ? Icons.grid_view_rounded
                    : id == 'unclassified'
                        ? Icons.folder_off_rounded
                        : Icons.folder_rounded,
                size: 14,
                color: isSelected ? AppColors.ink : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Builder(
                builder: (context) {
                  String prefix = '';
                  if (id != 'all' && id != 'unclassified' && !isShared) {
                    prefix = sharedWithFriendIds.isNotEmpty ? '👥 ' : '🔒 ';
                  }
                  return Text(
                    '$prefix$label',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.ink : AppColors.ink.withOpacity(0.8),
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddFolderButton() {
    return InkWell(
      onTap: _showAddFolderDialog,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.line, width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.muted),
            SizedBox(width: 4),
            Text('가방 추가', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // 아이템 그리드 빌더
  Widget _buildItemGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.ink));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.line),
                const SizedBox(height: 12),
                const Text('보관된 소장품이 없습니다.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UploadItemScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  label: const Text('첫 소장품 등록하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        // 카테고리 & 폴더 필터링
        var filteredItems = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // 1) 카테고리 필터
          if (_selectedCategory != '전체' && data['category'] != _selectedCategory) {
            return false;
          }

          // 2) 폴더 필터
          final List<dynamic> folderIds = data['folderIds'] ?? [];
          if (_selectedFolderId == 'unclassified') {
            return folderIds.isEmpty;
          } else if (_selectedFolderId != 'all') {
            return folderIds.contains(_selectedFolderId);
          }

          return true;
        }).toList();

        if (filteredItems.isEmpty) {
          return const Center(
            child: Text('조건에 맞는 소장품이 없습니다.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          );
        }

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0, // 1:1 정사각 뷰
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final doc = filteredItems[index];
            final item = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            final isSelected = _selectedItemIds.contains(docId);
            final String imageUrl = item['imageUrl'] ?? '';
            final bool isFavorite = item['isFavorite'] ?? false;

            return GestureDetector(
              onTap: () {
                if (_isEditMode) {
                  setState(() {
                    if (isSelected) {
                      _selectedItemIds.remove(docId);
                    } else {
                      _selectedItemIds.add(docId);
                    }
                  });
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemDetailScreen(docId: docId, item: item),
                    ),
                  );
                }
              },
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : (item['isSharedWithFriends'] == false ? AppColors.muted.withOpacity(0.3) : AppColors.line),
                        width: isSelected ? 2.0 : 0.8,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, fit: BoxFit.contain)
                              : const Icon(Icons.inventory_2_outlined, color: AppColors.line, size: 28),
                        ),
                      ),
                    ),
                  ),

                  // 비공개 아이콘 뱃지
                  if (item['isSharedWithFriends'] == false)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.lock_outline_rounded, size: 10, color: Colors.white),
                      ),
                    ),

                  // 최애템 뱃지
                  if (isFavorite)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                    ),

                  // 체크박스 오버레이 (편집 모드 시)
                  if (_isEditMode)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isSelected ? Icons.check : Icons.add,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 폴더 추가 팝업
  void _showAddFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Text('새 가방 만들기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            maxLength: 10,
            decoration: const InputDecoration(
              hintText: '가방 이름을 입력하세요 (예: 보드게임, 피규어)',
              hintStyle: TextStyle(fontSize: 13),
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
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await _firebaseService.createItemFolder(name);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('생성', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 일괄 폴더 담기
  void _showBulkFolderAssignDialog() {
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
              title: const Text('선택한 아이템을 어느 가방에 담을까요?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                              for (var itemId in _selectedItemIds) {
                                await _firebaseService.updateItemData(
                                  docId: itemId,
                                  updatedData: {
                                    'folderIds': [folder['id']],
                                    'folderId': folder['id'],
                                  },
                                );
                              }
                              setState(() {
                                _isEditMode = false;
                                _selectedItemIds.clear();
                              });
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

  // 일괄 삭제 다이얼로그
  void _showBulkDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('일괄 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('선택한 ${_selectedItemIds.length}개의 아이템을 완전히 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              for (var id in _selectedItemIds) {
                await _firebaseService.deleteItemData(id);
              }
              setState(() {
                _isEditMode = false;
                _selectedItemIds.clear();
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제하기', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // 개별 폴더(가방) 관리 팝업 (수정 / 삭제 / 친구 공유 제어)
  void _copyFolderShareLink(String folderId, String name, String type) {
    final myUid = _firebaseService.currentUserId;
    if (myUid == null) return;
    final shareUrl = "https://digital-closet-dev.web.app/#/share?userId=$myUid&folderId=$folderId&type=$type";
    Clipboard.setData(ClipboardData(text: shareUrl)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔗 "$name" 가방의 외부 공유 링크가 복사되었습니다!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _showFolderManageDialog(String folderId, String folderName, bool currentShareStatus, List<String> currentSharedFriendIds) {
    final controller = TextEditingController(text: folderName);
    bool isShared = currentShareStatus;
    
    List<String> selectedFriendIds = List<String>.from(currentSharedFriendIds);
    bool isTargetedFriendShare = selectedFriendIds.isNotEmpty;
    
    List<Map<String, dynamic>>? friendsList;
    bool isLoadingFriends = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (friendsList == null && !isLoadingFriends) {
            isLoadingFriends = true;
            _firebaseService.getFriends().then((list) {
              setDialogState(() {
                friendsList = list;
                isLoadingFriends = false;
              });
            });
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('가방 관리 ⚙️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(
                  icon: const Icon(Icons.link_rounded, size: 20, color: AppColors.ink),
                  tooltip: '외부 공유 링크 복사',
                  onPressed: () {
                    _copyFolderShareLink(folderId, folderName, 'item');
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: controller,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: '가방 이름 수정',
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.ink)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('친구에게 이 가방 공유하기', style: TextStyle(fontSize: 12, color: AppColors.ink)),
                        Switch(
                          value: isShared || isTargetedFriendShare,
                          activeColor: AppColors.accent,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val) {
                                isShared = true;
                                isTargetedFriendShare = false;
                              } else {
                                isShared = false;
                                isTargetedFriendShare = false;
                                selectedFriendIds.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (isShared || isTargetedFriendShare) ...[
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('모든 친구 공개', style: TextStyle(fontSize: 11)),
                              value: false,
                              groupValue: isTargetedFriendShare,
                              activeColor: Colors.black,
                              onChanged: (val) {
                                setDialogState(() {
                                  isShared = true;
                                  isTargetedFriendShare = false;
                                  selectedFriendIds.clear();
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('일부 친구 지정', style: TextStyle(fontSize: 11)),
                              value: true,
                              groupValue: isTargetedFriendShare,
                              activeColor: Colors.black,
                              onChanged: (val) {
                                setDialogState(() {
                                  isShared = false;
                                  isTargetedFriendShare = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (isTargetedFriendShare) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('공유할 친구 선택:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        if (isLoadingFriends)
                          const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        else if (friendsList == null || friendsList!.isEmpty)
                          const Text('등록된 친구가 없습니다.', style: TextStyle(fontSize: 11, color: Colors.grey))
                        else
                          Container(
                            constraints: const BoxConstraints(maxHeight: 120),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: friendsList!.map((friend) {
                                final String friendUid = friend['uid'] ?? '';
                                final String friendName = friend['nickname'] ?? '이름 없음';
                                final isSelected = selectedFriendIds.contains(friendUid);
                                return CheckboxListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                  title: Text(friendName, style: const TextStyle(fontSize: 12)),
                                  value: isSelected,
                                  activeColor: Colors.black,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedFriendIds.add(friendUid);
                                      } else {
                                        selectedFriendIds.remove(friendUid);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await _firebaseService.deleteItemFolder(folderId);
                  if (mounted) {
                    setState(() {
                      _selectedFolderId = 'all';
                    });
                    Navigator.pop(context);
                  }
                },
                child: const Text('삭제', style: TextStyle(color: AppColors.accent)),
              ),
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
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    final finalShareStatus = isShared && !isTargetedFriendShare;
                    await _firebaseService.updateItemFolder(
                      folderId, 
                      newName, 
                      isSharedWithFriends: finalShareStatus,
                      sharedWithFriendIds: selectedFriendIds,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('저장', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}
