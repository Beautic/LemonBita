import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'upload_screen.dart';
import 'clothing_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<QuerySnapshot> _clothesStream;
  String _selectedCategory = 'ALL';

  final List<Map<String, dynamic>> _categories = [
    {'name': 'ALL', 'icon': Icons.all_inclusive_rounded},
    {'name': '아우터', 'icon': Icons.layers_rounded},
    {'name': '상의', 'icon': Icons.checkroom_rounded},
    {'name': '하의', 'icon': Icons.straighten_rounded},
    {'name': '신발', 'icon': Icons.ice_skating_rounded},
    {'name': '액세서리', 'icon': Icons.watch_rounded},
    {'name': '기타', 'icon': Icons.more_horiz_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _clothesStream = _firebaseService.getClothesStream();
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
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                          return _buildClothingGridItem(doc.id, item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
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
                    child: Icon(
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
  Widget _buildClothingGridItem(String docId, Map<String, dynamic> item) {
    // 색상, 패턴 조합으로 임시 타이틀 생성
    String color = item['color'] ?? '';
    String pattern = item['pattern'] ?? '';
    String title = '$color $pattern'.trim();
    if (title.isEmpty) title = item['brand'] ?? '';
    if (title.isEmpty) title = item['category'] ?? '옷 정보 없음';

    String category = item['category'] ?? '';
    String fit = item['fit'] ?? '';
    String subtitle = fit.isNotEmpty ? '$category · $fit' : category;

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Hero(
                tag: docId,
                child: Image.network(
                  item['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[100],
                    child: const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                  ),
                ),
              ),
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
