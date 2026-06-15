import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../services/firebase_service.dart';
import '../utils/color_compatibility.dart';
import 'planned_ootd_detail_screen.dart';

class CanvasItem {
  final String docId;
  final String imageUrl;
  final String title;
  final String color;
  final String category;
  Uint8List? imageBytes;
  bool isLoadingBytes;

  Offset offset;
  double scale;
  double rotation;

  CanvasItem({
    required this.docId,
    required this.imageUrl,
    required this.title,
    this.color = '',
    this.category = '',
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.imageBytes,
    this.isLoadingBytes = false,
  });
}

class CoordinationCanvasScreen extends StatefulWidget {
  final String? editDocId;
  final List<dynamic>? initialCanvasItems;
  final String? friendUid;
  final String? friendNickname;

  const CoordinationCanvasScreen({
    super.key,
    this.editDocId,
    this.initialCanvasItems,
    this.friendUid,
    this.friendNickname,
  });

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

    if (widget.initialCanvasItems != null) {
      for (var item in widget.initialCanvasItems!) {
        final data = item as Map<String, dynamic>;
        final canvasItem = CanvasItem(
          docId: data['id'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          title: data['title'] ?? '',
          color: data['color'] ?? '',
          category: data['category'] ?? data['title'] ?? '',
          offset: Offset(
            (data['dx'] as num?)?.toDouble() ?? 100.0, 
            (data['dy'] as num?)?.toDouble() ?? 150.0
          ),
          scale: (data['scale'] as num?)?.toDouble() ?? 1.0,
          rotation: (data['rotation'] as num?)?.toDouble() ?? 0.0,
        );
        _items.add(canvasItem);
        _loadImageBytesFor(canvasItem);
      }
    }
  }

  Future<void> _loadPlannedOotds() async {
    setState(() { _isLoadingOotds = true; });
    try {
      final docs = await _firebaseService.getPlannedOOTDPage(targetUserId: widget.friendUid, limit: 20);
      setState(() {
        _plannedOotds = docs;
        _isLoadingOotds = false;
      });
    } catch (e) {
      debugPrint('Failed to load planned ootds: $e');
      setState(() { _isLoadingOotds = false; });
    }
  }

  void _loadImageBytesFor(CanvasItem item) async {
    if (item.imageBytes != null) return;
    setState(() {
      item.isLoadingBytes = true;
    });
    try {
      final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(item.imageUrl)}';
      final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          item.imageBytes = response.bodyBytes;
          item.isLoadingBytes = false;
        });
      } else {
        final directResp = await http.get(Uri.parse(item.imageUrl)).timeout(const Duration(seconds: 10));
        setState(() {
          item.imageBytes = directResp.bodyBytes;
          item.isLoadingBytes = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load image bytes for canvas: $e");
      setState(() {
        item.isLoadingBytes = false;
      });
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
      final imageBytes = byteData!.buffer.asUint8List();
      
      final taggedClothes = _items.map((item) => {
        'id': item.docId,
        'imageUrl': item.imageUrl,
        'title': item.title,
      }).toList();

      final canvasData = _items.map((item) => {
        'id': item.docId,
        'imageUrl': item.imageUrl,
        'title': item.title,
        'color': item.color,
        'category': item.category,
        'dx': item.offset.dx,
        'dy': item.offset.dy,
        'scale': item.scale,
        'rotation': item.rotation,
      }).toList();

      await _firebaseService.savePlannedOOTDData(
        imageBytes: imageBytes,
        taggedClothes: taggedClothes,
        canvasItems: canvasData,
        targetUserId: widget.friendUid,
        docId: widget.editDocId,
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

  Widget _buildClothesList(StateSetter setSheetState, ScrollController scrollController) {
    final targetUid = widget.friendUid ?? _firebaseService.currentUserId;
    if (targetUid == null) return const Center(child: Text('로그인이 필요합니다.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clothes')
          .where('userId', isEqualTo: targetUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
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

        // 임시 로컬 상태 변수를 위해 상위 호출자에서 관리해야 함 (여기서는 단순화)
        // 실제 구현시에는 StatefulBuilder 내부 변수 사용
        return Container(); // 예시: GridView 구현부 포함
      },
    );
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
                final targetUid = widget.friendUid ?? _firebaseService.currentUserId;
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('clothes')
                      .where('userId', isEqualTo: targetUid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('옷장에 등록된 옷이 없습니다.'));
                    }

                    final allDocs = snapshot.data!.docs;
                    final categoriesSet = <String>{};
                    for (var doc in allDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['category'] != null && data['category'].toString().isNotEmpty) {
                        categoriesSet.add(data['category'].toString());
                      }
                    }
                    final categories = ['전체', ...categoriesSet.toList()..sort()];
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
                                  final newItem = CanvasItem(
                                    docId: docs[index].id,
                                    imageUrl: data['imageUrl'] ?? '',
                                    title: data['category'] ?? '',
                                    color: data['color'] ?? '',
                                    category: data['category'] ?? '',
                                    offset: Offset(MediaQuery.of(context).size.width / 2 - 60, 150),
                                  );
                                  setState(() {
                                    _items.add(newItem);
                                    _selectedIndex = _items.length - 1;
                                  });
                                  _loadImageBytesFor(newItem);
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = '코디 캔버스';
    if (widget.friendNickname != null) {
      title = '${widget.friendNickname}님 코디 도와주기';
    } else if (widget.editDocId != null) {
      title = '코디 아이디어 수정';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              onScaleStart: (details) {
                if (_selectedIndex != null) {
                  setState(() {
                    final item = _items[_selectedIndex!];
                    _baseScale = item.scale;
                    _baseRotation = item.rotation;
                  });
                }
              },
              onScaleUpdate: (details) {
                if (_selectedIndex != null) {
                  setState(() {
                    final item = _items[_selectedIndex!];
                    item.offset += details.focalPointDelta;
                    item.scale = (_baseScale * details.scale).clamp(0.2, 5.0);
                    item.rotation = _baseRotation + details.rotation;
                  });
                }
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
                            onTapDown: (_) {
                              setState(() {
                                // 선택 시 맨 앞으로 가져오기
                                _items.removeAt(index);
                                _items.add(item);
                                _selectedIndex = _items.length - 1;
                              });
                            },
                            onTap: () {}, // 부모 onTap을 막기 위한 빈 핸들러
                            child: Transform.rotate(
                              angle: item.rotation,
                              child: Transform.scale(
                                scale: item.scale,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 150,
                                        maxHeight: 150,
                                      ),
                                      decoration: BoxDecoration(
                                        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                                      ),
                                      child: item.imageBytes != null
                                          ? Image.memory(
                                              item.imageBytes!,
                                              fit: BoxFit.contain,
                                            )
                                          : (item.isLoadingBytes
                                              ? const Center(
                                                  child: SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                )
                                              : Image.network(
                                                  _getProxyImageUrl(item.imageUrl),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                                )),
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
          
          // 1. 코디 추천 섹션 추가
          _buildRecommendationSection(),

          // 2. 하단 코디 아이디어 리스트 영역
          Container(
            height: 130,
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
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => PlannedOotdDetailScreen(plannedOotdId: doc.id)),
                                    );
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
        padding: const EdgeInsets.only(bottom: 320), // 추천 섹션 + 코디 아이디어 리스트 높이만큼 올림
        child: FloatingActionButton.extended(
          onPressed: _showClothesBottomSheet,
          backgroundColor: Colors.black,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('옷 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildRecommendationSection() {
    if (_items.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        alignment: Alignment.center,
        child: const Text(
          '캔버스에 옷을 추가하거나 선택하시면\n어울리는 색상의 옷을 추천해 드립니다. ✨',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
      );
    }

    final targetUid = widget.friendUid ?? _firebaseService.currentUserId;
    if (targetUid == null) return const SizedBox.shrink();

    // 캔버스에 추가된 모든 카테고리 및 색상 정보 추출
    final existingCategories = _items.map((e) => e.category).toSet();
    final existingColors = _items.map((e) => e.color).where((c) => c.isNotEmpty).toSet();

    String headerText = '';
    if (_items.length == 1) {
      final item = _items.first;
      headerText = '"${item.category} (${item.color.isEmpty ? '색상 미정' : item.color})"와 어울리는 추천 코디';
    } else {
      final colorsStr = existingColors.isEmpty ? '미정' : existingColors.join(', ');
      headerText = '"$colorsStr" 조합과 어울리는 추천 코디';
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, size: 18, color: Colors.deepOrangeAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    headerText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clothes')
                  .where('userId', isEqualTo: targetUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('추천할 옷이 옷장에 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)));
                }

                // 1. 다중 색상 전체 교집합 매칭 시도
                var recommendedDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final itemColor = data['color'] ?? '';
                  final itemCategory = data['category'] ?? '';
                  
                  // 이미 캔버스에 추가된 실물 옷은 추천에서 제외
                  if (_items.any((item) => item.docId == doc.id)) return false;
                  
                  // 이미 캔버스에 추가된 카테고리의 옷도 추천에서 제외
                  if (existingCategories.contains(itemCategory)) return false;
                  
                  // 캔버스 내 모든 옷들의 색상과 어울리는지 교집합 검사
                  bool allComp = true;
                  for (var baseCol in existingColors) {
                    if (!ColorCompatibility.isCompatible(baseCol, itemColor)) {
                      allComp = false;
                      break;
                    }
                  }
                  return allComp;
                }).toList();

                // 2. 만약 완벽히 매치되는 옷이 없으면, 가장 최근에 추가/선택된 옷 색상 1벌 기준 필터로 완화(Fallback Phase 1)
                if (recommendedDocs.isEmpty && _items.isNotEmpty) {
                  final lastItem = _items.last;
                  recommendedDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final itemColor = data['color'] ?? '';
                    final itemCategory = data['category'] ?? '';
                    
                    if (_items.any((item) => item.docId == doc.id)) return false;
                    if (existingCategories.contains(itemCategory)) return false;
                    
                    return ColorCompatibility.isCompatible(lastItem.color, itemColor);
                  }).toList();
                }

                // 3. 그래도 옷이 없다면, 무난한 기본 모노톤 및 파스텔톤 계열로 추천 (Fallback Phase 2)
                if (recommendedDocs.isEmpty) {
                  recommendedDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final itemColor = data['color'] ?? '';
                    final itemCategory = data['category'] ?? '';
                    
                    if (_items.any((item) => item.docId == doc.id)) return false;
                    if (existingCategories.contains(itemCategory)) return false;
                    
                    final normalized = ColorCompatibility.normalizeColor(itemColor);
                    return ['블랙', '화이트', '그레이', '아이보리', '베이지'].contains(normalized);
                  }).toList();
                }

                if (recommendedDocs.isEmpty) {
                  return const Center(child: Text('어울리는 다른 옷이 옷장에 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recommendedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = recommendedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final color = data['color'] ?? '';
                    final category = data['category'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        // 추천 옷 탭 시 캔버스에 추가
                        final newItem = CanvasItem(
                          docId: doc.id,
                          imageUrl: data['imageUrl'] ?? '',
                          title: category,
                          color: color,
                          category: category,
                          offset: Offset(MediaQuery.of(context).size.width / 2 - 60, 150),
                        );
                        setState(() {
                          _items.add(newItem);
                          _selectedIndex = _items.length - 1;
                        });
                        _loadImageBytesFor(newItem);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$category ($color) 옷이 코디 캔버스에 추가되었습니다!'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                child: Image.network(
                                  _getProxyImageUrl(data['imageUrl'] ?? ''),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    color.isEmpty ? '색상 미정' : color,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getProxyImageUrl(String url) {
    if (kIsWeb && url.isNotEmpty && !url.startsWith('data:')) {
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}';
    }
    return url;
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
