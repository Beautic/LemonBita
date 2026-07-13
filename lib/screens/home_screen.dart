import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'upload_screen.dart';
import '../theme/app_theme.dart';
import 'dart:ui' as ui;
import 'clothing_detail_screen.dart';
import 'search_clothes_screen.dart';
import '../utils/categories.dart';
import 'notification_screen.dart';
import '../services/weather_service.dart';
import '../utils/weather_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<QuerySnapshot> _clothesStream;
  late final Stream<QuerySnapshot> _ootdStream;
  String _selectedCategory = 'ALL';

  // 날씨 및 추천용 변수 추가
  double? _temperature;
  int? _weatherLevel;
  bool _isWeatherLoading = true;
  bool _isWeatherExpanded = false; // 기본값 접힘

  // 옷장 폴더용 변수 추가
  String _selectedFolderId = 'all';
  bool _isEditMode = false;
  final Set<String> _selectedClothingIds = {};

  final List<Map<String, dynamic>> _categories = [
    {'name': 'ALL', 'icon': Icons.all_inclusive_rounded},
    {'name': '상의', 'imageAsset': CategoryData.getIconPath('티셔츠')},
    {'name': '원피스', 'imageAsset': CategoryData.getIconPath('캐주얼 원피스')},
    {'name': '바지', 'imageAsset': CategoryData.getIconPath('청바지')},
    {'name': '치마', 'imageAsset': CategoryData.getIconPath('미니스커트')},
    {'name': '아우터', 'imageAsset': CategoryData.getIconPath('자켓')},
    {'name': '신발', 'imageAsset': CategoryData.getIconPath('스니커즈')},
    {'name': '가방', 'imageAsset': CategoryData.getIconPath('에코백')},
    {'name': '모자', 'imageAsset': CategoryData.getIconPath('캡')},
    {'name': '악세서리', 'icon': Icons.watch_rounded},
    {'name': '기타', 'icon': Icons.more_horiz_rounded},
  ];

  List<String> _activeCategories = ['상의', '원피스', '바지', '치마', '아우터', '신발', '가방', '모자', '악세서리', '기타'];
  List<String> _userCustomCategories = [];

  @override
  void initState() {
    super.initState();
    _clothesStream = _firebaseService.getClothesStream();
    _ootdStream = _firebaseService.getOOTDStream();
    _loadWeather();
    _loadActiveCategories();
  }

  Future<void> _loadActiveCategories() async {
    final list = await _firebaseService.getActiveCategories();
    final customList = await _firebaseService.getUserCustomCategories();
    if (mounted) {
      setState(() {
        _activeCategories = List<String>.from(list);
        _userCustomCategories = List<String>.from(customList);
      });
    }
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;
    setState(() => _isWeatherLoading = true);
    try {
      final temp = await WeatherService.fetchCurrentTemperature();
      final level = WeatherHelper.getLevelFromCelsius(temp);
      if (mounted) {
        setState(() {
          _temperature = temp;
          _weatherLevel = level;
          _isWeatherLoading = false;
        });
      }
    } catch (e) {
      debugPrint("🚩 Failed to load weather: $e");
      if (mounted) {
        setState(() => _isWeatherLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: (_isEditMode && _selectedClothingIds.isNotEmpty)
          ? SafeArea(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedClothingIds.length}개 선택됨',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    TextButton.icon(
                      onPressed: _showBulkFolderAssignDialog,
                      icon: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
                      label: const Text('폴더에 담기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      appBar: AppBar(
        title: Text(
          'MYVENTORY',
          style: AppText.mono.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16, color: AppColors.ink),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firebaseService.getNotificationsStream(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return !(data['isRead'] ?? false);
                }).length;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.black),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotificationScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchClothesScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ootdStream,
        builder: (context, ootdSnapshot) {
          if (ootdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          // 태그 횟수 계산
          Map<String, int> tagCounts = {};
          if (ootdSnapshot.hasData) {
            for (var doc in ootdSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              List<dynamic> taggedIds = data['taggedClothesIds'] ?? [];
              // 이전 데이터 호환 (taggedClothes 배열)
              if (taggedIds.isEmpty && data['taggedClothes'] != null) {
                taggedIds = (data['taggedClothes'] as List).map((e) => e['id']).toList();
              }
              for (var id in taggedIds) {
                tagCounts[id.toString()] = (tagCounts[id.toString()] ?? 0) + 1;
              }
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _clothesStream,
            builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final clothes = snapshot.data?.docs ?? [];
          
          // 1. 폴더 및 카테고리 필터링 (다중 편집 모드일 때는 폴더 필터링을 임시 해제하여 전체 옷 중에서 골라 담을 수 있게 합니다)
          var filteredClothes = clothes;
          if (!_isEditMode) {
            if (_selectedFolderId == 'unclassified') {
              filteredClothes = filteredClothes.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final List<dynamic>? folderIds = data['folderIds'];
                final oldFolderId = data['folderId'];
                final hasNoFolderIds = folderIds == null || folderIds.isEmpty;
                final hasNoOldFolderId = oldFolderId == null || oldFolderId.toString().isEmpty;
                return hasNoFolderIds && hasNoOldFolderId;
              }).toList();
            } else if (_selectedFolderId != 'all') {
              filteredClothes = filteredClothes.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final List<dynamic>? folderIds = data['folderIds'];
                final oldFolderId = data['folderId'];
                final inNewFolderIds = folderIds != null && folderIds.contains(_selectedFolderId);
                final inOldFolderId = oldFolderId == _selectedFolderId;
                return inNewFolderIds || inOldFolderId;
              }).toList();
            }
          }

          if (_selectedCategory != 'ALL') {
            filteredClothes = filteredClothes.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['category'] == _selectedCategory;
            }).toList();
          }

          // 2. 카테고리별 등록 벌 수 집계 및 내림차순 정렬
          final Map<String, int> categoryCounts = {};
          for (var doc in clothes) {
            final data = doc.data() as Map<String, dynamic>;
            final catName = data['category'] ?? '기타';
            categoryCounts[catName] = (categoryCounts[catName] ?? 0) + 1;
          }

          // 기본 카테고리와 사용자가 추가한 커스텀 카테고리를 병합
          final allCategories = [
            ..._categories,
            ..._userCustomCategories.map((name) => {
              'name': name,
              'icon': Icons.style, // 범용적인 예쁜 태그/스타일 아이콘
            }),
          ];

          // ALL 칩을 제외하고, 유저가 선택한 activeCategories 에 포함되는 카테고리만 동적 노출
          final dynamicCategories = allCategories.where((cat) {
            return cat['name'] != 'ALL' && _activeCategories.contains(cat['name']);
          }).toList();
          dynamicCategories.sort((a, b) {
            final countA = categoryCounts[a['name']] ?? 0;
            final countB = categoryCounts[b['name']] ?? 0;
            return countB.compareTo(countA); // 등록된 옷이 많은 순으로 내림차순
          });

          // ALL 칩을 맨 앞에 삽입하여 동적 최종 카테고리 목록 생성
          final finalCategories = [
            allCategories.firstWhere((cat) => cat['name'] == 'ALL'),
            ...dynamicCategories,
          ];

          return Column(
            children: [
              _buildWeatherRecommendationCard(clothes, tagCounts),
              _buildMergedFilterBar(finalCategories),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 4.0, right: 16.0, bottom: 4.0),
                child: Row(
                  children: [
                    Text(
                      '${filteredClothes.length} ITEMS',
                      style: AppText.mono.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isEditMode = !_isEditMode;
                          _selectedClothingIds.clear();
                        });
                      },
                      icon: Icon(
                        _isEditMode ? Icons.close_rounded : Icons.check_box_outlined,
                        size: 15,
                        color: _isEditMode ? AppColors.accent : AppColors.ink,
                      ),
                      label: Text(
                        _isEditMode ? '선택 취소' : '다중 선택',
                        style: TextStyle(
                          color: _isEditMode ? AppColors.accent : AppColors.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.line),
              Expanded(
                child: filteredClothes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('이 카테고리에는\n등록된 아이템이 없습니다.', 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredClothes.length + 1,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 7,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          if (index == filteredClothes.length) {
                            return const _EmptySlot();
                          }
                          final doc = filteredClothes[index];
                          final item = doc.data() as Map<String, dynamic>;
                          final count = tagCounts[doc.id] ?? 0;
                          return _buildClothingGridItem(doc.id, item, count);
                        },
                      ),
              ),
            ],
          );
        },
      ); // closes inner StreamBuilder
        }, // closes outer builder
      ), // closes outer StreamBuilder
    ); // closes Scaffold
  }

  Widget _buildMergedFilterBar(List<Map<String, dynamic>> finalCategories) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firebaseService.getClosetFoldersStream(),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? [];
        final List<Map<String, dynamic>> renderedCategories = [
          ...finalCategories,
          {'name': '설정', 'icon': Icons.settings_rounded, 'isSettingChip': true},
        ];

        return Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _buildFolderChip(id: 'all', name: '전체'),
              const SizedBox(width: 6),
              _buildFolderChip(id: 'unclassified', name: '미분류'),
              const SizedBox(width: 6),
              ...folders.map((folder) {
                final isShared = folder['isSharedWithFriends'] as bool? ?? true;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: _buildFolderChip(
                    id: folder['id'] as String,
                    name: folder['name'] as String,
                    isDeletable: true,
                    isShared: isShared,
                  ),
                );
              }),
              IconButton(
                icon: const Icon(
                  Icons.create_new_folder_outlined,
                  color: AppColors.muted,
                  size: 18,
                ),
                onPressed: _showCreateFolderDialog,
                tooltip: '폴더 만들기',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
              ),
              ...renderedCategories.map((category) {
                final isSetting = category['isSettingChip'] == true;
                final isSelected = _selectedCategory == category['name'];

                return GestureDetector(
                  onTap: () {
                    if (isSetting) {
                      _showCategoryCustomizerBottomSheet();
                    } else {
                      setState(() => _selectedCategory = category['name']);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.ink : AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? AppColors.ink : AppColors.line,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSetting) ...[
                          Icon(
                            category['icon'] as IconData,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                        ] else if (category.containsKey('imageAsset')) ...[
                          Image.asset(
                            category['imageAsset'] as String,
                            width: 13,
                            height: 13,
                            color: isSelected ? AppColors.surface : AppColors.ink,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.category_rounded,
                              color: isSelected ? AppColors.surface : AppColors.ink,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ] else ...[
                          Icon(
                            category['icon'] as IconData,
                            color: isSelected ? AppColors.surface : AppColors.ink,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          category['name'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.surface : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // 선호 카테고리 커스터마이저 바텀시트
  void _showCategoryCustomizerBottomSheet() {
    final List<String> allPresetNames = ['상의', '원피스', '바지', '치마', '아우터', '신발', '가방', '모자', '악세서리', '기타'];
    List<String> tempSelected = List<String>.from(_activeCategories);
    final TextEditingController customController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드 노출 시 시트가 위로 밀려나도록 설정
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allVisibleCategories = [...allPresetNames, ..._userCustomCategories];

            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0, // 키보드 높이만큼 바텀 마진 추가
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '카테고리 설정 ⚙️',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '자주 쓰는 카테고리만 골라 칩을 구성하고, 직접 새로운 카테고리를 추가할 수 있습니다.\n*직접 추가한 커스텀 카테고리(옷이 아닌 아이템)는 OOTD 코디 및 날씨 추천 대상에서 자동으로 제외됩니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customController,
                            maxLength: 10,
                            decoration: InputDecoration(
                              hintText: '새 카테고리 이름 입력 (최대 10자)',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              filled: true,
                              fillColor: const Color(0xFFF1F3F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final text = customController.text.trim();
                              if (text.isEmpty) return;
                              
                              if (allVisibleCategories.contains(text) || text == 'ALL') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('이미 존재하는 카테고리 이름입니다.')),
                                );
                                return;
                              }

                              setSheetState(() {
                                _userCustomCategories.add(text);
                                _activeCategories.add(text);
                                tempSelected.add(text);
                              });
                              setState(() {});

                              _firebaseService.updateUserCustomCategories(_userCustomCategories);
                              _firebaseService.updateActiveCategories(_activeCategories);

                              customController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("'$text' 카테고리가 신설되었습니다.")),
                              );
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: allVisibleCategories.length,
                      itemBuilder: (context, index) {
                        final name = allVisibleCategories[index];
                        final isChecked = tempSelected.contains(name);
                        final isCustom = _userCustomCategories.contains(name);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: Colors.black,
                                onChanged: (bool? value) {
                                  setSheetState(() {
                                    if (value == true) {
                                      if (!tempSelected.contains(name)) {
                                        tempSelected.add(name);
                                      }
                                    } else {
                                      if (tempSelected.length > 1) {
                                        tempSelected.remove(name);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('최소 하나의 카테고리는 선택되어야 합니다.')),
                                        );
                                      }
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCustom ? FontWeight.bold : FontWeight.w500,
                                    color: isCustom ? Colors.blueAccent : Colors.black87,
                                  ),
                                ),
                              ),
                              if (isCustom)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    setState(() {
                                      _userCustomCategories.remove(name);
                                      _activeCategories.remove(name);
                                      tempSelected.remove(name);
                                    });

                                    await _firebaseService.updateUserCustomCategories(_userCustomCategories);
                                    await _firebaseService.updateActiveCategories(_activeCategories);

                                    setSheetState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("'$name' 카테고리가 삭제되었습니다.")),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await _firebaseService.updateActiveCategories(tempSelected);
                          if (mounted) {
                            setState(() {
                              _activeCategories = tempSelected;
                              if (!_activeCategories.contains(_selectedCategory) && _selectedCategory != 'ALL') {
                                _selectedCategory = 'ALL';
                              }
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('카테고리 노출 설정이 저장되었습니다.')),
                            );
                          }
                        },
                        child: const Text('설정 저장하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  // 피드 그리드 아이템
  Widget _buildClothingGridItem(String docId, Map<String, dynamic> item, int tagCount) {
    final int washInterval = (item['washInterval'] as num?)?.toInt() ?? 0;
    final int lastWashedCount = (item['lastWashedCount'] as num?)?.toInt() ?? 0;
    final int washedSince = tagCount - lastWashedCount;
    final bool isWashRequired = washInterval > 0 && washedSince >= washInterval;

    final bool isFavorite = (item['isFavorite'] as bool?) ?? false;
    final bool isSelected = _selectedClothingIds.contains(docId);

    return GestureDetector(
      onTap: () {
        if (_isEditMode) {
          setState(() {
            if (isSelected) {
              _selectedClothingIds.remove(docId);
            } else {
              _selectedClothingIds.add(docId);
            }
          });
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClothingDetailScreen(docId: docId, item: item),
            ),
          ).then((_) => _loadActiveCategories()); // 상세에서 돌아올 때 즐겨찾기 상태 최신화를 위해 갱신
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slot,
          borderRadius: BorderRadius.circular(AppRadius.slot),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.line, width: isSelected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 누끼 이미지 (잘리지 않게 contain 적용, 패딩 10px 부여)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Hero(
                  tag: docId,
                  child: Image.network(
                    item['imageUrl'] ?? '',
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported,
                      size: 24,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
            // 즐겨찾기 - 우상단 붉은 삼각 노치
            if (isFavorite)
              Positioned(
                top: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(12, 12),
                  painter: CornerNotch(),
                ),
              ),
            // 세탁 필요 - 좌하단 선명한 파란색 알림 배지 복원 (가독성 극대화 및 테마 매칭)
            if (isWashRequired)
              Positioned(
                bottom: 4,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_laundry_service, size: 8, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        '세탁 필요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // 착용 횟수 - 우하단 모노스페이스 숫자
            if (tagCount > 0)
              Positioned(
                bottom: 4,
                right: 6,
                child: Text(
                  '$tagCount',
                  style: AppText.mono.copyWith(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // 다중 편집 모드 체크 배지
            if (_isEditMode)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white70,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.accent : Colors.black45,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('데이터를 불러오지 못했습니다.\n$error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // 날씨 맞춤형 추천 카드 빌더
  Widget _buildWeatherRecommendationCard(List<QueryDocumentSnapshot> clothes, Map<String, int> tagCounts) {
    final bool isClothingContext = _selectedCategory == 'ALL' || CategoryData.mainCategories.contains(_selectedCategory);
    if (!isClothingContext) return const SizedBox.shrink();

    if (_isWeatherLoading) {
      return Container(
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.line),
        ),
        child: const Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.ink),
          ),
        ),
      );
    }

    if (_temperature == null || _weatherLevel == null) return const SizedBox.shrink();

    final label = WeatherHelper.getLevelLabel(_weatherLevel!);

    final List<Map<String, dynamic>> scoredItems = [];
    for (var doc in clothes) {
      final data = doc.data() as Map<String, dynamic>;
      final String docId = doc.id;
      if (_userCustomCategories.contains(data['category'])) continue;
      final int washInterval = (data['washInterval'] as num?)?.toInt() ?? 0;
      final int lastWashedCount = (data['lastWashedCount'] as num?)?.toInt() ?? 0;
      final int tagCount = tagCounts[docId] ?? 0;
      final int washedSince = tagCount - lastWashedCount;
      final bool isWashRequired = washInterval > 0 && washedSince >= washInterval;
      if (isWashRequired) continue;

      final List<dynamic> wornLevels = data['wornWeatherLevels'] ?? [];
      int score = 0;
      final matchCount = wornLevels.where((l) => l == _weatherLevel).length;
      score += matchCount * 10;
      if (wornLevels.isEmpty) {
        final suitable = WeatherHelper.getSuitableLevels(
          category: data['category'] ?? '',
          subCategory: data['subCategory'] ?? '',
          material: data['material'] ?? '',
        );
        if (suitable.contains(_weatherLevel)) {
          score += 5;
        }
      }
      if (score > 0) {
        scoredItems.add({
          'docId': docId,
          'data': data,
          'score': score,
          'tagCount': tagCounts[docId] ?? 0,
        });
      }
    }
    scoredItems.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, color: AppColors.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                '${_temperature!.toStringAsFixed(1)}°',
                style: AppText.mono.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              Text(
                ' · $label',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (scoredItems.isNotEmpty)
            TextButton(
              onPressed: () {
                _showSmartRecommendationDialog(scoredItems);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '스마트 추천',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, color: AppColors.accent, size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSmartRecommendationDialog(List<Map<String, dynamic>> scoredItems) {
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
                    '스마트 날씨 추천 💡',
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
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: scoredItems.length,
                  itemBuilder: (context, index) {
                    final item = scoredItems[index];
                    final data = item['data'] as Map<String, dynamic>;
                    final String docId = item['docId'];
                    final int score = item['score'];

                    String color = data['color'] ?? '';
                    String pattern = data['pattern'] ?? '';
                    String title = '$color $pattern'.trim();
                    if (title.isEmpty) title = data['brand'] ?? '';
                    if (title.isEmpty) title = data['category'] ?? '아이템';

                    final isBest = score >= 10;

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
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
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
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isBest ? AppColors.accent : AppColors.ink,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isBest ? 'BEST 🔥' : '추천 ⭐',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 7,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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

  // ==== 옷장 폴더 UI 로직 추가 ====

  Widget _buildFolderChip({
    required String id, 
    required String name, 
    bool isDeletable = false, 
    bool isShared = false, 
    List<String> sharedWithFriendIds = const []
  }) {
    final isSelected = _selectedFolderId == id;
    
    String prefix = '';
    if (!isShared && isDeletable) {
      prefix = sharedWithFriendIds.isNotEmpty ? '👥 ' : '🔒 ';
    }
    final displayName = '$prefix$name';

    return GestureDetector(
      onTap: () {
        if (_selectedFolderId != id) {
          setState(() {
            _selectedFolderId = id;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppColors.ink : AppColors.line,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDeletable)
              Icon(Icons.folder_outlined, size: 13, color: isSelected ? AppColors.surface : AppColors.muted),
            if (isDeletable)
              const SizedBox(width: 4),
            Text(
              displayName,
              style: TextStyle(
                color: isSelected ? AppColors.surface : AppColors.ink,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
            if (isDeletable && isSelected) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _showFolderManageOptions(id, name, isShared, sharedWithFriendIds),
                child: Icon(
                  Icons.settings_outlined,
                  size: 13,
                  color: isSelected ? AppColors.surface : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('새 옷장 폴더 만들기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '폴더 이름을 입력하세요 (예: 여름 셔츠)',
              hintStyle: TextStyle(fontSize: 14),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await _firebaseService.createClosetFolder(name);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('폴더 생성 실패: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('만들기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

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

  void _showFolderManageOptions(String folderId, String name, bool isShared, List<String> sharedFriendIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  '폴더 관리: $name',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                title: const Text('설정 변경하기 (이름 & 공유)'),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameFolderDialog(folderId, name, isShared, sharedFriendIds);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded, color: Colors.black87),
                title: const Text('외부 공유 링크 복사하기'),
                onTap: () {
                  Navigator.pop(context);
                  _copyFolderShareLink(folderId, name, 'closet');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('삭제하기', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteFolderConfirmDialog(folderId, name);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameFolderDialog(String folderId, String currentName, bool currentShareStatus, List<String> currentSharedFriendIds) {
    final controller = TextEditingController(text: currentName);
    bool isShared = currentShareStatus;
    
    // 친구 선택을 위한 상태
    List<String> selectedFriendIds = List<String>.from(currentSharedFriendIds);
    bool isTargetedFriendShare = selectedFriendIds.isNotEmpty;
    
    List<Map<String, dynamic>>? friendsList;
    bool isLoadingFriends = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 친구 목록 로드
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
              backgroundColor: Colors.white,
              title: const Text('폴더 설정 변경', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: '새 폴더 이름을 입력하세요',
                          hintStyle: TextStyle(fontSize: 14),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('친구에게 이 폴더 공유하기', style: TextStyle(fontSize: 12)),
                          Switch(
                            value: isShared || isTargetedFriendShare,
                            activeColor: AppColors.accent,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val) {
                                  isShared = true; // 기본적으로 전체 공개
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      try {
                        // isSharedWithFriends 필드는 '일부 친구 지정'일 때 false를 유지합니다.
                        final finalShareStatus = isShared && !isTargetedFriendShare;
                        await _firebaseService.updateClosetFolder(
                          folderId, 
                          newName, 
                          isSharedWithFriends: finalShareStatus,
                          sharedWithFriendIds: selectedFriendIds,
                        );
                        if (mounted) Navigator.pop(context);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('설정 변경 실패: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('변경', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  void _showDeleteFolderConfirmDialog(String folderId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('폴더 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
            '\'$name\' 폴더를 삭제하시겠습니까?\n폴더를 삭제해도 옷장 안의 옷들은 삭제되지 않고 [미분류] 상태로 보관됩니다.',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _firebaseService.deleteClosetFolder(folderId);
                  setState(() {
                    if (_selectedFolderId == folderId) {
                      _selectedFolderId = 'all';
                    }
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('폴더 삭제 실패: $e')),
                    );
                  }
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showBulkFolderAssignDialog() {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelectedFolderIds = [];
        if (_selectedFolderId != 'all' && _selectedFolderId != 'unclassified') {
          tempSelectedFolderIds.add(_selectedFolderId);
        }
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('선택한 옷 폴더 담기 (중복 가능)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firebaseService.getClosetFoldersStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                    }
                    final folders = snapshot.data ?? [];
                    if (folders.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          '생성된 옷장 폴더가 없습니다. 폴더를 먼저 생성해 주세요.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      );
                    }
                    
                    return ListView(
                      shrinkWrap: true,
                      children: folders.map((folder) {
                        final String id = folder['id'] as String;
                        final isChecked = tempSelectedFolderIds.contains(id);
                        return CheckboxListTile(
                          title: Text(folder['name'] as String),
                          value: isChecked,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                tempSelectedFolderIds.add(id);
                              } else {
                                tempSelectedFolderIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    if (tempSelectedFolderIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('폴더를 1개 이상 선택해 주세요.')),
                      );
                      return;
                    }
                    try {
                      await _firebaseService.addClothesToFolders(
                        _selectedClothingIds.toList(),
                        tempSelectedFolderIds,
                      );
                      setState(() {
                        _isEditMode = false;
                        _selectedClothingIds.clear();
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('선택한 옷들이 폴더에 추가되었습니다.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('일괄 담기 실패: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('추가', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UploadScreen()),
        );
      },
      child: CustomPaint(
        painter: DashedSlotPainter(),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: AppColors.muted,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class DashedSlotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(AppRadius.slot),
      ));

    double dashWidth = 6, dashSpace = 4, distance = 0;
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        ui.Path extractPath = pathMetric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CornerNotch extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
