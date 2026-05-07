import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'upload_screen.dart';
import 'clothing_detail_screen.dart';
import 'search_clothes_screen.dart';
import '../utils/categories.dart';

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

  @override
  void initState() {
    super.initState();
    _clothesStream = _firebaseService.getClothesStream();
    _ootdStream = _firebaseService.getOOTDStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'MY CLOSET',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black),
        ),
        actions: [
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
          
          final filteredClothes = _selectedCategory == 'ALL' 
            ? clothes 
            : clothes.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['category'] == _selectedCategory;
              }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == 'ALL' ? 'All Items' : _selectedCategory,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _selectedCategory == 'ALL'
                          ? '${clothes.length} items · ${_categories.length - 1} categories'
                          : '${filteredClothes.length} items',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              _buildStoryCategories(),
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
              Expanded(
                child: filteredClothes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text('이 카테고리에는\n등록된 옷이 없습니다.', 
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredClothes.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.6, // 이미지(정방형) + 텍스트 2줄 공간
                        ),
                        itemBuilder: (context, index) {
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

  // 상단 인스타 스토리 형태의 카테고리
  Widget _buildStoryCategories() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['name'];
          
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category['name']),
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey[300]!,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                      color: Colors.white,
                    ),
                    child: category.containsKey('imageAsset')
                        ? Center(
                            child: Image.asset(
                              category['imageAsset'],
                              width: 32,
                              height: 32,
                              color: isSelected ? Colors.black : Colors.grey[600],
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.category_rounded,
                                color: isSelected ? Colors.black : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                          )
                        : Icon(
                            category['icon'],
                            color: isSelected ? Colors.black : Colors.grey[600],
                            size: 24,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 피드 그리드 아이템
  Widget _buildClothingGridItem(String docId, Map<String, dynamic> item, int tagCount) {
    // 색상, 패턴 조합으로 임시 타이틀 생성
    String color = item['color'] ?? '';
    String pattern = item['pattern'] ?? '';
    String title = '$color $pattern'.trim();
    if (title.isEmpty) title = item['brand'] ?? '';
    if (title.isEmpty) title = item['category'] ?? '옷 정보 없음';

    String category = item['category'] ?? '';
    String subCategory = item['subCategory'] ?? '';
    String subtitle = subCategory.isNotEmpty ? '$category · $subCategory' : category;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClothingDetailScreen(docId: docId, item: item),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Hero(
                    tag: docId,
                    child: Image.network(
                      item['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[100],
                        child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                if (tagCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark, size: 10, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '$tagCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
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
}
