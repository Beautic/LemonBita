import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../services/firebase_service.dart';
import '../utils/color_compatibility.dart';
import '../utils/weather_helper.dart';
import '../services/weather_service.dart';
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
  String _currentTemplate = 'none'; // 'none', 'editorial', 'catalog', 'polaroid'
  double _lastCanvasWidth = 320.0;
  double _lastCanvasHeight = 400.0;

  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  List<QueryDocumentSnapshot> _plannedOotds = [];
  bool _isLoadingOotds = true;

  int _selectedTemperatureLevel = 3; // 기본값: 선선한 날 (17~22°C)
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _loadPlannedOotds();
    _initializeTodayWeather();

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

  void _initializeTodayWeather() async {
    setState(() { _isLoadingWeather = true; });
    try {
      final temp = await WeatherService.fetchCurrentTemperature();
      final level = WeatherHelper.getLevelFromCelsius(temp);
      if (mounted) {
        setState(() {
          _selectedTemperatureLevel = level;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to initialize weather: $e");
      if (mounted) {
        setState(() { _isLoadingWeather = false; });
      }
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
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined, color: Colors.black87),
            tooltip: '저장된 코디 아이디어',
            onPressed: _showSavedOotdsBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.black87),
            tooltip: '룩북 자동 배치',
            onPressed: _autoArrangeCanvasItems,
          ),
          TextButton(
            onPressed: _isSaving ? null : _saveCanvas,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('저장', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: const Color(0xFFF1F3F5), // 연한 회색 배경으로 9:16 캔버스 카드를 부각시킴
        child: Column(
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
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: RepaintBoundary(
                            key: _canvasKey,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double canvasW = constraints.maxWidth;
                                final double canvasH = constraints.maxHeight;
                                
                                // 화면 크기 변경 시 치수 캐싱
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && (_lastCanvasWidth != canvasW || _lastCanvasHeight != canvasH)) {
                                    setState(() {
                                      _lastCanvasWidth = canvasW;
                                      _lastCanvasHeight = canvasH;
                                    });
                                  }
                                });
                                
                                return Container(
                                  width: double.infinity,
                                  color: Colors.white,
                                  child: Stack(
                                    children: [
                      // 템플릿 별 배경 및 오버레이 적용
                      if (_currentTemplate == 'editorial') ...[
                        // 베이지색 배경
                        Positioned.fill(
                          child: Container(color: const Color(0xFFF2ECE4)),
                        ),
                        // 얇은 내부 선 테두리
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26, width: 0.8),
                            ),
                          ),
                        ),
                        // 상단 럭셔리 타이틀
                        Positioned(
                          top: 28,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Text(
                                'E S S E N T I A L S',
                                style: TextStyle(
                                  fontFamily: 'Serif',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 4.0,
                                  color: Colors.black.withOpacity(0.75),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'STYLE DIARY & ARCHIVE',
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 2.0,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 하단 정보 텍스트
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAILY LOOKBOOK',
                                style: TextStyle(fontSize: 8, letterSpacing: 1.5, color: Colors.black.withOpacity(0.6), fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'VOL. 01 / ${DateTime.now().year}.${DateTime.now().month.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 8, letterSpacing: 1.0, color: Colors.black.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_currentTemplate == 'catalog') ...[
                        // 카탈로그 회색 배경
                        Positioned.fill(
                          child: Container(color: const Color(0xFFECEFF1)),
                        ),
                        // 모눈그리드
                        Positioned.fill(
                          child: CustomPaint(painter: GridPainter(color: Colors.black.withOpacity(0.04), spacing: 25)),
                        ),
                        // 사이드 라벨 바
                        Positioned(
                          top: 20,
                          left: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SELECTED ITEMS',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Colors.black87),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 80,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ),
                        // 우측 하단 제품 일련번호 연출
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'CLOSET CAT. NO. ${_items.length}',
                                style: const TextStyle(fontSize: 8, fontFamily: 'monospace', color: Colors.black54),
                              ),
                              Text(
                                'TEMP: ${widget.friendNickname != null ? "SUGGESTED" : "MY OOTD"}',
                                style: const TextStyle(fontSize: 7, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_currentTemplate == 'polaroid') ...[
                        // 따뜻한 린넨 배경
                        Positioned.fill(
                          child: Container(color: const Color(0xFFF9F5F0)),
                        ),
                        // 대형 폴라로이드 형태의 흰색 여백 마스킹
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 64),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                          ),
                        ),
                        // 폴라로이드 하단 넓은 흰색 영역에 손글씨 텍스트
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              const Text(
                                'Today\'s Mood Board',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateTime.now().year}.${DateTime.now().month}.${DateTime.now().day}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.black45,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // 템플릿 없을 때 기본 그라데이션 또는 깔끔 연회색 배경
                        Positioned.fill(
                          child: Container(color: const Color(0xFFF8F9FA)),
                        ),
                        Positioned.fill(
                          child: CustomPaint(painter: GridPainter()),
                        ),
                      ],
                      
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
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 150.0 * item.scale,
                                    height: 150.0 * item.scale,
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
                          );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  ),
),
),
),
          
          // 1. 코디 추천 섹션 추가 (하단에 상시 노출)
          _buildRecommendationSection(isBottomSheet: false),
          
          // 2. 룩북 템플릿 칩 바
          Container(
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _buildTemplateChip('none', '기본 캔버스'),
                const SizedBox(width: 8),
                _buildTemplateChip('editorial', '에디토리얼'),
                const SizedBox(width: 8),
                _buildTemplateChip('catalog', '카탈로그'),
                const SizedBox(width: 8),
                _buildTemplateChip('polaroid', '폴라로이드'),
              ],
            ),
          ),
        ],
      ),
    ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 285), // 룩북 바 (55px) + 추천 바 (220px) + 여백 높이만큼 올림
        child: FloatingActionButton.extended(
          onPressed: _showClothesBottomSheet,
          backgroundColor: Colors.black,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('옷 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _autoArrangeCanvasItems() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('캔버스에 옷이 없어서 정렬할 수 없습니다.')),
      );
      return;
    }

    setState(() {
      final double baseW = _lastCanvasWidth;
      final double baseH = _lastCanvasHeight;

      // 1. 카테고리 구성 상세 집계
      final Map<String, List<CanvasItem>> categorizedItems = {
        'outer': [],
        'top': [],
        'bottom': [],
        'shoes': [],
        'bag': [],
        'accessory': [],
      };

      for (var item in _items) {
        final cat = item.category.toLowerCase();
        if (cat.contains('아우터') || cat.contains('자켓') || cat.contains('코트') || cat.contains('가디건') || cat.contains('outer') || cat.contains('jacket')) {
          categorizedItems['outer']!.add(item);
        } else if (cat.contains('상의') || cat.contains('셔츠') || cat.contains('티셔츠') || cat.contains('니트') || cat.contains('top') || cat.contains('shirt')) {
          categorizedItems['top']!.add(item);
        } else if (cat.contains('하의') || cat.contains('바지') || cat.contains('팬츠') || cat.contains('스커트') || cat.contains('bottom') || cat.contains('pants')) {
          categorizedItems['bottom']!.add(item);
        } else if (cat.contains('신발') || cat.contains('슈즈') || cat.contains('shoes') || cat.contains('sneakers')) {
          categorizedItems['shoes']!.add(item);
        } else if (cat.contains('가방') || cat.contains('백') || cat.contains('bag')) {
          categorizedItems['bag']!.add(item);
        } else {
          categorizedItems['accessory']!.add(item);
        }
      }

      // 2. 가변형 레이아웃 분기 판단
      // 캔버스 내 메인 의류들이 각각 1개 이하이고 총 개수가 3개 이하인 경우 '단일 1열 착장 세트 모드'로 분류
      final bool isSingleOutfitSet = _items.length <= 3 &&
                                    categorizedItems['top']!.length <= 1 &&
                                    categorizedItems['bottom']!.length <= 1 &&
                                    categorizedItems['outer']!.length <= 1 &&
                                    categorizedItems['shoes']!.length <= 1;

      final Map<String, int> categoryCount = {};

      for (var item in _items) {
        final cat = item.category.toLowerCase();
        String type = 'accessory';
        if (cat.contains('아우터') || cat.contains('자켓') || cat.contains('코트') || cat.contains('가디건') || cat.contains('outer') || cat.contains('jacket')) {
          type = 'outer';
        } else if (cat.contains('상의') || cat.contains('셔츠') || cat.contains('티셔츠') || cat.contains('니트') || cat.contains('top') || cat.contains('shirt')) {
          type = 'top';
        } else if (cat.contains('하의') || cat.contains('바지') || cat.contains('팬츠') || cat.contains('스커트') || cat.contains('bottom') || cat.contains('pants')) {
          type = 'bottom';
        } else if (cat.contains('신발') || cat.contains('슈즈') || cat.contains('shoes') || cat.contains('sneakers')) {
          type = 'shoes';
        } else if (cat.contains('가방') || cat.contains('백') || cat.contains('bag')) {
          type = 'bag';
        }

        categoryCount[type] = (categoryCount[type] ?? 0) + 1;
        final int index = categoryCount[type]! - 1;

        double scale = 0.70;
        double rotation = 0.0;
        Offset center = Offset(baseW * 0.5, baseH * 0.5);

        if (isSingleOutfitSet) {
          // [수직 1열 단일 코디 모드] - 템플릿별로 Y축을 유연하게 조정하여 텍스트 겹침 차단
          if (_currentTemplate == 'polaroid') {
            // 폴라로이드는 하단 64px의 텍스트/여백을 침범하지 않도록 Y축 오프셋을 상향 밀착 정렬하며, 옷 크기를 축소하여 겹침 방지
            switch (type) {
              case 'outer':
                scale = 0.58;
                center = Offset(baseW * 0.16 + (index * 12.0), baseH * 0.24 + (index * 10.0));
                break;
              case 'top':
                scale = 0.58;
                center = Offset(baseW * 0.50, baseH * 0.22 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.58;
                center = Offset(baseW * 0.50, baseH * 0.48 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.50;
                center = Offset(baseW * 0.50, baseH * 0.72 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.50;
                center = Offset(baseW * 0.82, baseH * 0.45 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.42;
                center = Offset(baseW * 0.18, baseH * 0.45 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          } else if (_currentTemplate == 'editorial') {
            // 에디토리얼은 상단 에센셜 밑의 작은 글자("STYLE DIARY & ARCHIVE" 약 90px 점유)를 침범하지 않도록 Y축 시작점을 대폭 하향 조정하고, 상하/좌우 겹침을 완전 제거
            switch (type) {
              case 'outer':
                scale = 0.70;
                center = Offset(baseW * 0.18 + (index * 12.0), baseH * 0.38 + (index * 10.0));
                break;
              case 'top':
                scale = 0.70;
                center = Offset(baseW * 0.50, baseH * 0.38 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.70;
                center = Offset(baseW * 0.50, baseH * 0.68 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.55;
                center = Offset(baseW * 0.50, baseH * 0.90 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.55;
                center = Offset(baseW * 0.82, baseH * 0.60 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.45;
                center = Offset(baseW * 0.18, baseH * 0.60 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          } else if (_currentTemplate == 'catalog') {
            // 카탈로그는 좌상단 블랙 타이틀 바 높이를 회피하여 정렬하며, 겹침 제거
            switch (type) {
              case 'outer':
                scale = 0.70;
                center = Offset(baseW * 0.18 + (index * 12.0), baseH * 0.35 + (index * 10.0));
                break;
              case 'top':
                scale = 0.70;
                center = Offset(baseW * 0.50, baseH * 0.35 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.70;
                center = Offset(baseW * 0.50, baseH * 0.66 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.55;
                center = Offset(baseW * 0.50, baseH * 0.88 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.55;
                center = Offset(baseW * 0.82, baseH * 0.58 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.45;
                center = Offset(baseW * 0.18, baseH * 0.58 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          } else {
            // 기본 캔버스는 가득 차게 밸런스 배치하되 겹침 제거
            switch (type) {
              case 'outer':
                scale = 0.70;
                center = Offset(baseW * 0.18 + (index * 12.0), baseH * 0.26 + (index * 10.0));
                break;
              case 'top':
                scale = 0.70;
                center = Offset(baseW * 0.50, baseH * 0.26 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.70;
                center = Offset(baseW * 0.50, baseH * 0.60 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.55;
                center = Offset(baseW * 0.50, baseH * 0.86 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.55;
                center = Offset(baseW * 0.82, baseH * 0.50 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.45;
                center = Offset(baseW * 0.18, baseH * 0.50 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          }
        } else {
          // [다중 격자 콜라주 모드] - 템플릿별로 Y축과 scale을 유연하게 조정하여 겹침 차단
          if (_currentTemplate == 'polaroid') {
            // 폴라로이드는 아래쪽 64px 마진을 감안하여 Y축 위치를 상향 축소 조절하며 모든 스케일을 55%로 줄임
            switch (type) {
              case 'outer':
                scale = 0.55;
                center = Offset(baseW * 0.22 + (index * 12.0), baseH * 0.20 + (index * 10.0));
                break;
              case 'top':
                scale = 0.55;
                center = Offset(baseW * 0.78 + (index * 12.0), baseH * 0.20 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.55;
                center = Offset(baseW * 0.22 + (index * 12.0), baseH * 0.54 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.55;
                center = Offset(baseW * 0.78 + (index * 15.0), baseH * 0.54 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.50;
                center = Offset(baseW * 0.50 + (index * 15.0), baseH * 0.38 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.40;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.10 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          } else if (_currentTemplate == 'editorial') {
            // 에디토리얼 상단 글귀와 하단 라인 간섭을 피해 Y축을 위아래로 넓히고 겹침 완전 차단
            switch (type) {
              case 'outer':
                scale = 0.65;
                center = Offset(baseW * 0.24 + (index * 12.0), baseH * 0.38 + (index * 10.0));
                break;
              case 'top':
                scale = 0.65;
                center = Offset(baseW * 0.76 + (index * 12.0), baseH * 0.38 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.65;
                center = Offset(baseW * 0.24 + (index * 12.0), baseH * 0.72 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.60;
                center = Offset(baseW * 0.76 + (index * 15.0), baseH * 0.72 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.52;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.55 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.42;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.25 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          } else if (_currentTemplate == 'catalog') {
            // 카탈로그는 좌상단 검은색 띠 헤더 높이만큼 Y축을 6%씩 하향 조정하고 가로/세로 분산
            switch (type) {
              case 'outer':
                scale = 0.65;
                center = Offset(baseW * 0.24 + (index * 12.0), baseH * 0.35 + (index * 10.0));
                break;
              case 'top':
                scale = 0.65;
                center = Offset(baseW * 0.76 + (index * 12.0), baseH * 0.35 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.65;
                center = Offset(baseW * 0.24 + (index * 12.0), baseH * 0.70 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.60;
                center = Offset(baseW * 0.76 + (index * 15.0), baseH * 0.70 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.52;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.52 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.42;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.22 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          } else {
            // 기본 캔버스는 노멀 분할 구도로 비겹침 배열
            switch (type) {
              case 'outer':
                scale = 0.65;
                center = Offset(baseW * 0.24 + (index * 12.0), baseH * 0.26 + (index * 10.0));
                break;
              case 'top':
                scale = 0.65;
                center = Offset(baseW * 0.76 + (index * 12.0), baseH * 0.26 + (index * 10.0));
                break;
              case 'bottom':
                scale = 0.65;
                center = Offset(baseW * 0.24 + (index * 12.0), baseH * 0.66 + (index * 15.0));
                break;
              case 'shoes':
                scale = 0.60;
                center = Offset(baseW * 0.76 + (index * 15.0), baseH * 0.66 + (index * 10.0));
                break;
              case 'bag':
                scale = 0.52;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.46 + (index * 15.0));
                rotation = -0.10;
                break;
              case 'accessory':
                scale = 0.42;
                center = Offset(baseW * 0.50 + (index * 12.0), baseH * 0.15 + (index * 15.0));
                rotation = 0.08;
                break;
            }
          }
        }

        final double itemSize = 150.0 * scale;
        final double dx = center.dx - (itemSize * 0.5);
        final double dy = center.dy - (itemSize * 0.5);

        item.offset = Offset(dx, dy);
        item.scale = scale;
        item.rotation = rotation;
      }

      // 레이어 순서(Z-Index) 정렬
      _items.sort((a, b) {
        final aType = _getArrangementRank(a.category);
        final bType = _getArrangementRank(b.category);
        return aType.compareTo(bType);
      });

      _selectedIndex = null; // 선택 해제
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('코디 아이템들이 기하학적으로 자동 정렬되었습니다! ✨'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  int _getArrangementRank(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('아우터') || cat.contains('자켓') || cat.contains('코트') || cat.contains('가디건') || cat.contains('outer') || cat.contains('jacket')) {
      return 0; // 맨 뒤
    } else if (cat.contains('상의') || cat.contains('셔츠') || cat.contains('티셔츠') || cat.contains('니트') || cat.contains('top') || cat.contains('shirt')) {
      return 1;
    } else if (cat.contains('하의') || cat.contains('바지') || cat.contains('팬츠') || cat.contains('스커트') || cat.contains('bottom') || cat.contains('pants')) {
      return 2;
    } else if (cat.contains('신발') || cat.contains('슈즈') || cat.contains('shoes') || cat.contains('sneakers')) {
      return 3;
    } else if (cat.contains('가방') || cat.contains('백') || cat.contains('bag')) {
      return 4;
    }
    return 5; // 액세서리는 맨 앞
  }

  void _showSavedOotdsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.collections_bookmark_outlined, color: Colors.black87, size: 20),
                        SizedBox(width: 6),
                        Text(
                          '저장된 코디 아이디어',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoadingOotds
                    ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : _plannedOotds.isEmpty
                        ? const Center(child: Text('저장된 코디 아이디어가 없습니다.', style: TextStyle(fontSize: 13, color: Colors.grey)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _plannedOotds.length,
                            itemBuilder: (context, index) {
                              final doc = _plannedOotds[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => PlannedOotdDetailScreen(plannedOotdId: doc.id)),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey[100],
                                    border: Border.all(color: Colors.grey[200]!),
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
        );
      },
    );
  }

  Widget _buildRecommendationSection({bool isBottomSheet = false}) {
    if (_items.isEmpty) {
      return Container(
        height: isBottomSheet ? double.infinity : 220,
        decoration: BoxDecoration(
          color: Colors.white,
          border: isBottomSheet ? null : Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        alignment: Alignment.center,
        child: const Text(
          '캔버스에 옷을 추가하거나 선택하시면\n어울리는 색상과 날씨의 옷을 추천해 드립니다. ✨',
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
      height: isBottomSheet ? double.infinity : 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isBottomSheet ? null : Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
          
          // 실시간 날씨 기온 필터 칩 바 추가
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [4, 3, 2, 1].map((level) {
                final isSelected = _selectedTemperatureLevel == level;
                final label = WeatherHelper.getLevelLabel(level);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      label, 
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.black87
                      )
                    ),
                    selected: isSelected,
                    selectedColor: Colors.black,
                    backgroundColor: Colors.grey[100],
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedTemperatureLevel = level;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
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

                // 1. 다중 색상 전체 교집합 매칭 시도 + 날씨(기온) 필터링 (유추 기온 + 실제 OOTD 착용 이력 합집합)
                var recommendedDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final itemColor = data['color'] ?? '';
                  final itemCategory = data['category'] ?? '';
                  final itemSubCategory = data['subCategory'] ?? '';
                  final itemMaterial = data['material'] ?? '';
                  
                  // 이미 캔버스에 추가된 실물 옷은 추천에서 제외
                  if (_items.any((item) => item.docId == doc.id)) return false;
                  
                  // 이미 캔버스에 추가된 카테고리의 옷도 추천에서 제외
                  if (existingCategories.contains(itemCategory)) return false;

                  // 날씨/기온 레벨 호환성 검사 (유추 기온 레벨 + 실제 OOTD 착용 이력 합집합)
                  final suitableLevels = WeatherHelper.getSuitableLevels(
                    category: itemCategory,
                    subCategory: itemSubCategory,
                    material: itemMaterial,
                  );
                  final List<dynamic> wornLevels = data['wornWeatherLevels'] ?? [];
                  final allSuitable = {...suitableLevels, ...wornLevels.cast<int>()};
                  if (!allSuitable.contains(_selectedTemperatureLevel)) return false;
                  
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

                // 2. 만약 완벽히 매치되는 옷이 없으면, 가장 최근에 추가/선택된 옷 색상 1벌 기준 필터로 완화 (단, 날씨 기온 필터는 유지)
                if (recommendedDocs.isEmpty && _items.isNotEmpty) {
                  final lastItem = _items.last;
                  recommendedDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final itemColor = data['color'] ?? '';
                    final itemCategory = data['category'] ?? '';
                    final itemSubCategory = data['subCategory'] ?? '';
                    final itemMaterial = data['material'] ?? '';
                    
                    if (_items.any((item) => item.docId == doc.id)) return false;
                    if (existingCategories.contains(itemCategory)) return false;

                    // 날씨/기온 레벨 호환성 검사 (유추 기온 레벨 + 실제 OOTD 착용 이력 합집합)
                    final suitableLevels = WeatherHelper.getSuitableLevels(
                      category: itemCategory,
                      subCategory: itemSubCategory,
                      material: itemMaterial,
                    );
                    final List<dynamic> wornLevels = data['wornWeatherLevels'] ?? [];
                    final allSuitable = {...suitableLevels, ...wornLevels.cast<int>()};
                    if (!allSuitable.contains(_selectedTemperatureLevel)) return false;
                    
                    return ColorCompatibility.isCompatible(lastItem.color, itemColor);
                  }).toList();
                }

                // 3. 그래도 옷이 없다면, 기온에 적합한 무난한 기본 모노톤 및 파스텔톤 계열로 추천 (단, 날씨 기온 필터는 유지)
                if (recommendedDocs.isEmpty) {
                  recommendedDocs = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final itemColor = data['color'] ?? '';
                    final itemCategory = data['category'] ?? '';
                    final itemSubCategory = data['subCategory'] ?? '';
                    final itemMaterial = data['material'] ?? '';
                    
                    if (_items.any((item) => item.docId == doc.id)) return false;
                    if (existingCategories.contains(itemCategory)) return false;

                    // 날씨/기온 레벨 호환성 검사 (유추 기온 레벨 + 실제 OOTD 착용 이력 합집합)
                    final suitableLevels = WeatherHelper.getSuitableLevels(
                      category: itemCategory,
                      subCategory: itemSubCategory,
                      material: itemMaterial,
                    );
                    final List<dynamic> wornLevels = data['wornWeatherLevels'] ?? [];
                    final allSuitable = {...suitableLevels, ...wornLevels.cast<int>()};
                    if (!allSuitable.contains(_selectedTemperatureLevel)) return false;
                    
                    final normalized = ColorCompatibility.normalizeColor(itemColor);
                    return ['블랙', '화이트', '그레이', '아이보리', '베이지'].contains(normalized);
                  }).toList();
                }

                if (recommendedDocs.isEmpty) {
                  return const Center(child: Text('선택한 날씨와 어울리는 다른 옷이 옷장에 없습니다.', style: TextStyle(fontSize: 11, color: Colors.grey)));
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
                        if (isBottomSheet) {
                          Navigator.pop(context);
                        }
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

  Widget _buildTemplateChip(String templateId, String name) {
    final isSelected = _currentTemplate == templateId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTemplate = templateId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              templateId == 'none'
                  ? Icons.dashboard_customize_outlined
                  : templateId == 'editorial'
                      ? Icons.menu_book_rounded
                      : templateId == 'catalog'
                          ? Icons.grid_view_rounded
                          : Icons.filter_frames_rounded,
              size: 14,
              color: isSelected ? Colors.white : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 점선 그리드 배경 그리기
class GridPainter extends CustomPainter {
  final Color? color;
  final double spacing;

  GridPainter({this.color, this.spacing = 20.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

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
