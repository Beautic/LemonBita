import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class CanvasItem {
  final String docId;
  final String imageUrl;
  final String title;

  Offset offset;
  double scale;
  double rotation;

  CanvasItem({
    required this.docId,
    required this.imageUrl,
    required this.title,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class CoordinationCanvasScreen extends StatefulWidget {
  const CoordinationCanvasScreen({super.key});

  @override
  State<CoordinationCanvasScreen> createState() => _CoordinationCanvasScreenState();
}

class _CoordinationCanvasScreenState extends State<CoordinationCanvasScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalKey _canvasKey = GlobalKey();

  List<CanvasItem> _items = [];
  int? _selectedIndex;
  bool _isSaving = false;

  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  List<QueryDocumentSnapshot> _plannedOotds = [];
  bool _isLoadingOotds = true;

  @override
  void initState() {
    super.initState();
    _loadPlannedOotds();
  }

  Future<void> _loadPlannedOotds() async {
    setState(() { _isLoadingOotds = true; });
    try {
      final docs = await _firebaseService.getPlannedOOTDPage(limit: 20);
      setState(() {
        _plannedOotds = docs;
        _isLoadingOotds = false;
      });
    } catch (e) {
      debugPrint('Failed to load planned ootds: $e');
      setState(() { _isLoadingOotds = false; });
    }
  }

  Future<void> _saveCanvas() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('캔버스에 옷을 먼저 추가해주세요.')),
      );
      return;
    }

    setState(() {
      _selectedIndex = null; // 선택 해제하여 삭제 버튼 숨김
      _isSaving = true;
    });

    // 화면 갱신 대기
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final imageUrl = await _firebaseService.uploadImage(pngBytes, 'png');

      final taggedClothes = _items.map((item) => {
        'id': item.docId,
        'imageUrl': item.imageUrl,
        'title': item.title,
      }).toList();

      // 중복 제거
      final uniqueTaggedClothes = <String, Map<String, dynamic>>{};
      for (var c in taggedClothes) {
        uniqueTaggedClothes[c['id'] as String] = c;
      }

      await _firebaseService.savePlannedOOTDData(
        imageUrl: imageUrl,
        taggedClothes: uniqueTaggedClothes.values.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('코디 아이디어가 저장되었습니다!')),
        );
        setState(() {
          _items.clear();
          _isSaving = false;
        });
        _loadPlannedOotds();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
        setState(() { _isSaving = false; });
      }
    }
  }

  void _showClothesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String selectedCategory = '전체';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firebaseService.getClothesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('옷장에 등록된 옷이 없습니다.'));
                }

                final allDocs = snapshot.data!.docs;

                // 동적으로 카테고리 목록 생성
                final categoriesSet = <String>{};
                for (var doc in allDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['category'] != null && data['category'].toString().isNotEmpty) {
                    categoriesSet.add(data['category'].toString());
                  }
                }
                final categories = ['전체', ...categoriesSet.toList()..sort()];

                // 선택된 카테고리로 필터링
                final docs = selectedCategory == '전체'
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['category'] == selectedCategory;
                      }).toList();

                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('추가할 옷 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (categories.length > 1)
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = cat == selectedCategory;
                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  selectedCategory = cat;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.black87,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _items.add(CanvasItem(
                                  docId: docs[index].id,
                                  imageUrl: data['imageUrl'] ?? '',
                                  title: data['category'] ?? '',
                                  offset: Offset(MediaQuery.of(context).size.width / 2 - 60, 150),
                                ));
                                _selectedIndex = _items.length - 1;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[100],
                                image: DecorationImage(
                                  image: NetworkImage(data['imageUrl'] ?? ''),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('가상 코디 캔버스', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveCanvas,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('저장', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() { _selectedIndex = null; });
              },
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF8F9FA), // 연한 회색 배경
                  child: Stack(
                    children: [
                      // 그리드 무늬 (선택 사항)
                      Positioned.fill(
                        child: CustomPaint(painter: GridPainter()),
                      ),
                      
                      // 캔버스 아이템들
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = _selectedIndex == index;

                        return Positioned(
                          left: item.offset.dx,
                          top: item.offset.dy,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                // 선택 시 맨 앞으로 가져오기
                                _items.removeAt(index);
                                _items.add(item);
                                _selectedIndex = _items.length - 1;
                              });
                            },
                            onScaleStart: (details) {
                              setState(() {
                                _items.removeAt(index);
                                _items.add(item);
                                _selectedIndex = _items.length - 1;
                                _baseScale = item.scale;
                                _baseRotation = item.rotation;
                              });
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                if (_selectedIndex != null) {
                                  final selectedItem = _items[_selectedIndex!];
                                  selectedItem.offset += details.focalPointDelta;
                                  selectedItem.scale = (_baseScale * details.scale).clamp(0.2, 5.0);
                                  selectedItem.rotation = _baseRotation + details.rotation;
                                }
                              });
                            },
                            child: Transform.rotate(
                              angle: item.rotation,
                              child: Transform.scale(
                                scale: item.scale,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                                      ),
                                      child: Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: -10,
                                        top: -10,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _items.removeAt(_selectedIndex!);
                                              _selectedIndex = null;
                                            });
                                          },
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.black,
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 하단 코디 아이디어 리스트 영역
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('저장된 코디 아이디어', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Expanded(
                  child: _isLoadingOotds
                      ? const Center(child: CircularProgressIndicator(color: Colors.black))
                      : _plannedOotds.isEmpty
                          ? const Center(child: Text('저장된 코디 아이디어가 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _plannedOotds.length,
                              itemBuilder: (context, index) {
                                final doc = _plannedOotds[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return GestureDetector(
                                  onTap: () {
                                    // TODO: 코디 아이디어를 OOTD로 변환하거나 자세히 보기
                                  },
                                  child: Container(
                                    width: 80,
                                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[100],
                                      image: DecorationImage(
                                        image: NetworkImage(data['imageUrl'] ?? ''),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 140), // 하단 리스트 위로 올리기
        child: FloatingActionButton.extended(
          onPressed: _showClothesBottomSheet,
          backgroundColor: Colors.black,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('옷 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// 점선 그리드 배경 그리기
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    const double spacing = 20.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
