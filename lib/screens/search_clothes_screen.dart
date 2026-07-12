import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../utils/categories.dart';
import 'clothing_detail_screen.dart';

class SearchClothesScreen extends StatefulWidget {
  final bool isSelectionMode;
  final Set<String>? initialSelectedIds;

  const SearchClothesScreen({
    super.key,
    this.isSelectionMode = false,
    this.initialSelectedIds,
  });

  @override
  State<SearchClothesScreen> createState() => _SearchClothesScreenState();
}

class _SearchClothesScreenState extends State<SearchClothesScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<QueryDocumentSnapshot> _allClothes = [];
  List<QueryDocumentSnapshot> _filteredClothes = [];
  bool _isLoading = true;

  String? _selectedMajorCategory;
  String? _selectedSubCategory;
  String? _selectedColor;

  final List<String> _commonColors = [
    '블랙', '화이트', '그레이', '네이비', '블루', '레드', '핑크', '그린', '옐로우', '베이지', '브라운', '기타'
  ];

  final Set<String> _selectedIds = {};

  List<String> _customCategories = [];

  @override
  void initState() {
    super.initState();
    if (widget.isSelectionMode && widget.initialSelectedIds != null) {
      _selectedIds.addAll(widget.initialSelectedIds!);
    }
    _fetchAllClothes();
    _loadCustomCategories();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _loadCustomCategories() async {
    final list = await _firebaseService.getUserCustomCategories();
    if (mounted) {
      setState(() {
        _customCategories = List<String>.from(list);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllClothes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clothes')
          .where('userId', isEqualTo: _firebaseService.currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _allClothes = snapshot.docs;
        _filteredClothes = _allClothes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching clothes for search: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _filteredClothes = _allClothes.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // 1. 대분류 검사
        if (_selectedMajorCategory != null && data['category'] != _selectedMajorCategory) {
          return false;
        }
        
        // 2. 소분류 검사
        if (_selectedSubCategory != null && data['subCategory'] != _selectedSubCategory) {
          return false;
        }

        // 3. 색상 검사
        if (_selectedColor != null) {
          final docColor = (data['color'] ?? '').toString().toLowerCase();
          if (!docColor.contains(_selectedColor!.toLowerCase())) {
            return false;
          }
        }

        // 4. 자유 텍스트 검사 (query)
        if (query.isNotEmpty) {
          final searchableText = [
            data['category'] ?? '',
            data['subCategory'] ?? '',
            data['color'] ?? '',
            data['brand'] ?? '',
            data['pattern'] ?? '',
            data['tags'] ?? '',
            data['memo'] ?? '',
          ].join(' ').toLowerCase();

          if (!searchableText.contains(query)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedMajorCategory = null;
      _selectedSubCategory = null;
      _selectedColor = null;
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '브랜드, 태그, 패턴 등으로 검색',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 16),
        ),
        actions: widget.isSelectionMode
            ? [
                TextButton(
                  onPressed: () {
                    List<Map<String, dynamic>> selectedItems = [];
                    for (var doc in _allClothes) {
                      if (_selectedIds.contains(doc.id)) {
                        final data = doc.data() as Map<String, dynamic>;
                        String title = '${data['color'] ?? ''} ${data['pattern'] ?? ''}'.trim();
                        if (title.isEmpty) title = data['brand'] ?? '';
                        if (title.isEmpty) title = data['category'] ?? '옷 정보 없음';

                        selectedItems.add({
                          'id': doc.id,
                          'imageUrl': data['imageUrl'] ?? '',
                          'title': title,
                        });
                      }
                    }
                    Navigator.pop(context, selectedItems);
                  },
                  child: const Text('완료', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 8),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(130), // 필터 영역 높이
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              // 대분류 필터
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('초기화', style: TextStyle(fontSize: 12)),
                      onSelected: (_) => _resetFilters(),
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    const SizedBox(width: 8),
                    ...[...CategoryData.mainCategories, ..._customCategories].map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(cat, style: const TextStyle(fontSize: 12)),
                          selected: _selectedMajorCategory == cat,
                          selectedColor: Colors.black,
                          labelStyle: TextStyle(color: _selectedMajorCategory == cat ? Colors.white : Colors.black),
                          onSelected: (selected) {
                            setState(() {
                              _selectedMajorCategory = selected ? cat : null;
                              _selectedSubCategory = null; // 대분류가 바뀌면 소분류 초기화
                            });
                            _applyFilters();
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              // 소분류 필터 (대분류가 선택된 경우에만 표시)
              if (_selectedMajorCategory != null && CategoryData.getSubCategories(_selectedMajorCategory!).isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Row(
                    children: CategoryData.getSubCategories(_selectedMajorCategory!).map((subCat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(subCat, style: const TextStyle(fontSize: 12)),
                          selected: _selectedSubCategory == subCat,
                          selectedColor: Colors.grey[800],
                          labelStyle: TextStyle(color: _selectedSubCategory == subCat ? Colors.white : Colors.black87),
                          onSelected: (selected) {
                            setState(() => _selectedSubCategory = selected ? subCat : null);
                            _applyFilters();
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (_selectedMajorCategory != null) const SizedBox(height: 8),
              // 색상 필터
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: _commonColors.map((color) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(color, style: const TextStyle(fontSize: 12)),
                        selected: _selectedColor == color,
                        selectedColor: Colors.grey[800],
                        labelStyle: TextStyle(color: _selectedColor == color ? Colors.white : Colors.black87),
                        onSelected: (selected) {
                          setState(() => _selectedColor = selected ? color : null);
                          _applyFilters();
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _filteredClothes.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _filteredClothes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.6,
                  ),
                  itemBuilder: (context, index) {
                    final doc = _filteredClothes[index];
                    final item = doc.data() as Map<String, dynamic>;
                    return _buildClothingGridItem(doc.id, item);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '조건에 맞는 옷이 없습니다.',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildClothingGridItem(String docId, Map<String, dynamic> item) {
    String title = '${item['color'] ?? ''} ${item['pattern'] ?? ''}'.trim();
    if (title.isEmpty) title = item['brand'] ?? '';
    if (title.isEmpty) title = item['category'] ?? '옷 정보 없음';

    String category = item['category'] ?? '';
    String subCategory = item['subCategory'] ?? '';
    String subtitle = subCategory.isNotEmpty ? '$category · $subCategory' : category;

    final bool isSelected = _selectedIds.contains(docId);

    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedIds.remove(docId);
            } else {
              _selectedIds.add(docId);
            }
          });
        } else {
          // 상세화면 갔다가 돌아왔을 때 데이터가 변경되었을 수 있으므로 재로드
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClothingDetailScreen(docId: docId, item: item),
            ),
          ).then((_) => _fetchAllClothes());
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: widget.isSelectionMode && isSelected
                        ? Border.all(color: Colors.black, width: 3)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['imageUrl'] ?? '',
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                if (widget.isSelectionMode && isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
