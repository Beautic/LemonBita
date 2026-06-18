import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import 'clothing_detail_screen.dart';

class ClosetAnalyticsScreen extends StatefulWidget {
  const ClosetAnalyticsScreen({super.key});

  @override
  State<ClosetAnalyticsScreen> createState() => _ClosetAnalyticsScreenState();
}

class _ClosetAnalyticsScreenState extends State<ClosetAnalyticsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<QuerySnapshot> _clothesStream;
  late final Stream<QuerySnapshot> _ootdStream;

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
          '옷장 통계 분석 📊',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        foregroundColor: Colors.black,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _ootdStream,
        builder: (context, ootdSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: _clothesStream,
            builder: (context, clothesSnapshot) {
              if (clothesSnapshot.connectionState == ConnectionState.waiting ||
                  ootdSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.black));
              }

              if (clothesSnapshot.hasError || ootdSnapshot.hasError) {
                return const Center(child: Text('통계 데이터를 불러오지 못했습니다.'));
              }

              final clothes = clothesSnapshot.data?.docs ?? [];
              final ootds = ootdSnapshot.data?.docs ?? [];

              if (clothes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        '등록된 옷이 없어\n통계를 분석할 수 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              // 1. 태그 횟수 계산
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

              // 2. 카테고리 분포 통계
              Map<String, int> categoryCounts = {};
              for (var doc in clothes) {
                final data = doc.data() as Map<String, dynamic>;
                final category = data['category'] ?? '기타';
                categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
              }

              // 3. 컬러 분포 통계
              Map<String, int> colorCounts = {};
              for (var doc in clothes) {
                final data = doc.data() as Map<String, dynamic>;
                final rawColor = data['color'] as String? ?? '';
                final color = rawColor.trim().isEmpty ? '미정' : rawColor.trim();
                colorCounts[color] = (colorCounts[color] ?? 0) + 1;
              }

              // 4. 최애 템 & 장롱 면허 템 선별
              final List<Map<String, dynamic>> scoredClothes = clothes.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'docId': doc.id,
                  'data': data,
                  'tagCount': tagCounts[doc.id] ?? 0,
                };
              }).toList();

              // 최애 템: 많이 입은 순서 정렬
              final favoriteClothes = List<Map<String, dynamic>>.from(scoredClothes)
                ..sort((a, b) => (b['tagCount'] as int).compareTo(a['tagCount'] as int));

              // 장롱 면허 템: 입은 적이 없는 옷
              final unusedClothes = scoredClothes.where((item) => item['tagCount'] == 0).toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 요약 카드
                    _buildSummaryCard(clothes.length, ootds.length, unusedClothes.length),
                    const SizedBox(height: 24),

                    // 카테고리 분포
                    const Text('카테고리 비율 🧥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildCategoryChart(categoryCounts, clothes.length),
                    const SizedBox(height: 24),

                    // 컬러 분포
                    const Text('선호 컬러 🎨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildColorDistribution(colorCounts, clothes.length),
                    const SizedBox(height: 24),

                    // 최애 템 TOP 3
                    const Text('자주 입은 최애 템 TOP 3 🔥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildFavoritesSection(favoriteClothes.take(3).toList()),
                    const SizedBox(height: 24),

                    // 장롱 면허 템 목록
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('잠자고 있는 의류 💤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${unusedClothes.length}개 발견', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildUnusedClothesSection(unusedClothes),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // 상단 대시보드 요약 블록
  Widget _buildSummaryCard(int totalClothes, int totalOotd, int unusedCount) {
    final activeRate = totalClothes > 0 ? ((totalClothes - unusedCount) / totalClothes * 100).toStringAsFixed(1) : '0';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem('전체 의류', '$totalClothes개', Colors.white),
              _buildSummaryItem('등록 OOTD', '$totalOotd회', Colors.white),
              _buildSummaryItem('의류 활용도', '$activeRate%', Colors.purpleAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // 카테고리 가로 바 차트
  Widget _buildCategoryChart(Map<String, int> counts, int total) {
    final sortedList = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sortedList.map((entry) {
            final percentage = entry.value / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${entry.value}개 (${(percentage * 100).toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[100],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 컬러 분포 가로 진행 표시줄
  Widget _buildColorDistribution(Map<String, int> counts, int total) {
    final sortedList = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sortedList.map((entry) {
            final percentage = entry.value / total;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _presetColorValue(entry.key),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    flex: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[100],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // 최애 의류 TOP 3 렌더링
  Widget _buildFavoritesSection(List<Map<String, dynamic>> items) {
    if (items.isEmpty || items.first['tagCount'] == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text('아직 코디에 태그된 이력이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final data = item['data'] as Map<String, dynamic>;
        final String docId = item['docId'];
        final int count = item['tagCount'];

        String color = data['color'] ?? '';
        String pattern = data['pattern'] ?? '';
        String title = '$color $pattern'.trim();
        if (title.isEmpty) title = data['brand'] ?? '';
        if (title.isEmpty) title = data['category'] ?? '아이템';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ClothingDetailScreen(docId: docId, item: data)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    data['imageUrl'] ?? '',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(data['category'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${index + 1}위 · $count회 착용',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 장롱 면허 템 가로 스크롤 섹션
  Widget _buildUnusedClothesSection(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text('장롱 면허 템이 없습니다! 훌륭합니다 🎉', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return SizedBox(
      height: 120,
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
          if (title.isEmpty) title = data['category'] ?? '옷';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClothingDetailScreen(docId: docId, item: data)),
              );
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: NetworkImage(data['imageUrl'] ?? ''),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 색상 프리셋 문자열을 실제 Color로 매칭
  Color _presetColorValue(String name) {
    switch (name) {
      case '블랙': return Colors.black;
      case '화이트': return Colors.white;
      case '아이보리': return const Color(0xFFFFFFF0);
      case '베이지': return const Color(0xFFF5F5DC);
      case '그레이': return Colors.grey;
      case '차콜': return const Color(0xFF36454F);
      case '네이비': return const Color(0xFF000080);
      case '브라운': return Colors.brown;
      case '카키': return const Color(0xFFBDB76B);
      case '와인': return const Color(0xFF722F37);
      case '레드': return Colors.red;
      case '오렌지': return Colors.orange;
      case '옐로우': return Colors.yellow;
      case '그린': return Colors.green;
      case '민트': return const Color(0xFF98FF98);
      case '스카이블루': return Colors.lightBlueAccent;
      case '블루': return Colors.blue;
      case '퍼플': return Colors.purple;
      case '핑크': return Colors.pink;
      default: return Colors.blueGrey;
    }
  }
}
