import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<QuerySnapshot> _clothesStream;
  String? _selectedCategory; // null이면 대시보드 표시

  final List<Map<String, dynamic>> _categories = [
    {'name': '아우터', 'icon': Icons.layers_rounded, 'color': Colors.blueAccent},
    {'name': '상의', 'icon': Icons.checkroom_rounded, 'color': Colors.orangeAccent},
    {'name': '하의', 'icon': Icons.straighten_rounded, 'color': Colors.greenAccent},
    {'name': '신발', 'icon': Icons.ice_skating_rounded, 'color': Colors.purpleAccent},
    {'name': '액세서리', 'icon': Icons.watch_rounded, 'color': Colors.redAccent},
    {'name': '기타', 'icon': Icons.more_horiz_rounded, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _clothesStream = _firebaseService.getClothesStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedCategory ?? '나만의 디지털 옷장',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: '로그아웃',
            onPressed: () async {
              await _firebaseService.logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _clothesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final clothes = snapshot.data?.docs ?? [];
          
          if (_selectedCategory == null) {
            return _buildCategoryDashboard(clothes);
          }

          final filteredClothes = clothes.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] == _selectedCategory;
          }).toList();

          return _buildClothesGrid(filteredClothes);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadScreen()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
        label: const Text('옷 추가하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 8,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // 1. 카테고리 대시보드 (첫 화면)
  Widget _buildCategoryDashboard(List<QueryDocumentSnapshot> allClothes) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '무엇을 입으시겠어요?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '총 ${allClothes.length}개의 아이템이 보관되어 있습니다.',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final count = allClothes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['category'] == category['name'];
                }).length;

                return _buildCategoryCard(category, count);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 카테고리 개별 카드
  Widget _buildCategoryCard(Map<String, dynamic> category, int count) {
    return InkWell(
      onTap: () => setState(() => _selectedCategory = category['name']),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (category['color'] as Color).withOpacity(0.2),
              (category['color'] as Color).withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: (category['color'] as Color).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category['icon'],
              size: 40,
              color: category['color'],
            ),
            const SizedBox(height: 12),
            Text(
              category['name'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$count items',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. 옷 그리드 뷰 (카테고리 선택 시)
  Widget _buildClothesGrid(List<QueryDocumentSnapshot> clothes) {
    if (clothes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('이 카테고리에는\n등록된 옷이 없습니다.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: clothes.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final item = clothes[index].data() as Map<String, dynamic>;
          return _buildClothingCard(item);
        },
      ),
    );
  }

  Widget _buildClothingCard(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item['imageUrl']!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: Text(
                  item['tags'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            Text('데이터를 불러오지 못했습니다.\n$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

