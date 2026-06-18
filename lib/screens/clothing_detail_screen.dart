import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../utils/categories.dart';
import '../utils/brands.dart';
import '../services/bg_removal_service.dart';
import '../utils/image_filters.dart';
import 'package:image_picker/image_picker.dart';
import 'ootd_selection_screen.dart';
class ClothingDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> item;

  const ClothingDetailScreen({
    super.key,
    required this.docId,
    required this.item,
  });

  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

class _ClothingDetailScreenState extends State<ClothingDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  late TextEditingController _brandController;
  late TextEditingController _sizeController;
  late TextEditingController _tagsController;
  late TextEditingController _memoController;
  late TextEditingController _colorController;
  late TextEditingController _patternController;
  late TextEditingController _materialController;
  late TextEditingController _fitController;
  late TextEditingController _lengthController;
  late String _selectedCategory;
  late String _selectedSubCategory;
  bool _isLoading = false;
  bool _isRemovingBg = false;
  
  // 누끼 완료 후 캐싱 변수
  Uint8List? _removedBgLocalBytes;

  late String _currentImageUrl;
  late String _originalImageUrl;
  
  String? _selectedColorPreset;
  bool _isCustomColor = false;

  // 세탁 관리 상태 변수 추가
  int _washInterval = 0;
  int _lastWashedCount = 0;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _localImageBytes;
  Uint8List? _originalLocalImageBytes;

  final List<Map<String, dynamic>> _colorPresets = [
    {'name': '블랙', 'color': Colors.black},
    {'name': '화이트', 'color': Colors.white},
    {'name': '아이보리', 'color': const Color(0xFFFFFFF0)},
    {'name': '베이지', 'color': const Color(0xFFF5F5DC)},
    {'name': '그레이', 'color': Colors.grey},
    {'name': '차콜', 'color': const Color(0xFF36454F)},
    {'name': '네이비', 'color': const Color(0xFF000080)},
    {'name': '브라운', 'color': Colors.brown},
    {'name': '카키', 'color': const Color(0xFFBDB76B)},
    {'name': '와인', 'color': const Color(0xFF722F37)},
    {'name': '레드', 'color': Colors.red},
    {'name': '오렌지', 'color': Colors.orange},
    {'name': '옐로우', 'color': Colors.yellow},
    {'name': '그린', 'color': Colors.green},
    {'name': '민트', 'color': const Color(0xFF98FF98)},
    {'name': '스카이블루', 'color': Colors.lightBlueAccent},
    {'name': '블루', 'color': Colors.blue},
    {'name': '퍼플', 'color': Colors.purple},
    {'name': '핑크', 'color': Colors.pink},
  ];

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.item['imageUrl'];
    _originalImageUrl = widget.item['imageUrl'];
    _brandController = TextEditingController(text: widget.item['brand'] ?? '');
    _sizeController = TextEditingController(text: widget.item['size'] ?? '');
    _tagsController = TextEditingController(text: widget.item['tags'] ?? '');
    _memoController = TextEditingController(text: widget.item['memo'] ?? '');
    
    final initialColor = widget.item['color'] ?? '';
    _colorController = TextEditingController(text: initialColor);
    
    if (initialColor.isNotEmpty) {
      final presetExists = _colorPresets.any((p) => p['name'] == initialColor);
      if (presetExists) {
        _selectedColorPreset = initialColor;
        _isCustomColor = false;
      } else {
        _selectedColorPreset = null;
        _isCustomColor = true;
      }
    }
    
    _patternController = TextEditingController(text: widget.item['pattern'] ?? '');
    _materialController = TextEditingController(text: widget.item['material'] ?? '');
    _fitController = TextEditingController(text: widget.item['fit'] ?? '');
    _lengthController = TextEditingController(text: widget.item['length'] ?? '');
    
    _selectedCategory = widget.item['category'] ?? CategoryData.mainCategories.first;
    if (!CategoryData.mainCategories.contains(_selectedCategory)) {
      _selectedCategory = CategoryData.mainCategories.first;
    }
    
    _selectedSubCategory = widget.item['subCategory'] ?? '';
    if (_selectedSubCategory.isNotEmpty && !CategoryData.getSubCategories(_selectedCategory).contains(_selectedSubCategory)) {
      _selectedSubCategory = '';
    }

    _washInterval = widget.item['washInterval'] ?? 0;
    _lastWashedCount = widget.item['lastWashedCount'] ?? 0;
    
  }

  @override
  void dispose() {
    _brandController.dispose();
    _sizeController.dispose();
    _tagsController.dispose();
    _memoController.dispose();
    _colorController.dispose();
    _patternController.dispose();
    _materialController.dispose();
    _fitController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  Future<void> _changeImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        _originalLocalImageBytes = bytes;
      });
    }
  }

  Future<void> _removeBackground() async {
    setState(() => _isRemovingBg = true);
    try {
      Uint8List? originalBytes;
      
      if (_localImageBytes != null) {
        originalBytes = _localImageBytes;
      } else {
        originalBytes = await _firebaseService.downloadImage(_currentImageUrl);
        if (originalBytes == null) {
          throw Exception('이미지를 불러올 수 없습니다.');
        }
      }

      final flatBytes = await BgRemovalService.flattenImageToJpeg(originalBytes!);
      final resultBytes = await BgRemovalService.removeBackground(flatBytes);
      
      setState(() {
        _localImageBytes = resultBytes;
        _removedBgLocalBytes = resultBytes; // 보정 완료된 최종 누끼 이미지 캐싱
        if (_originalLocalImageBytes == null) {
          _originalLocalImageBytes = originalBytes;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('누끼 제거 및 화면 맞춤 정렬이 완료되었습니다.\n등록할 때 옷을 평평하게 잘 펴서 촬영해주시면 더욱 깔끔해집니다!'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('배경 제거 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRemovingBg = false);
      }
    }
  }

  Future<void> _updateInfo() async {
    setState(() => _isLoading = true);
    try {
      String imageUrlToSave = _currentImageUrl;
      if (_localImageBytes != null) {
        imageUrlToSave = await _firebaseService.uploadImage(_localImageBytes!, 'png');
      }

      await _firebaseService.updateClothingData(
        docId: widget.docId,
        updatedData: {
          'imageUrl': imageUrlToSave,
          'brand': _brandController.text,
          'size': _sizeController.text,
          'tags': _tagsController.text,
          'memo': _memoController.text,
          'color': _colorController.text,
          'pattern': _patternController.text,
          'material': _materialController.text,
          'fit': _fitController.text,
          'length': _lengthController.text,
          'category': _selectedCategory,
          'subCategory': _selectedSubCategory,
          'washInterval': _washInterval,
          'lastWashedCount': _lastWashedCount,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보가 성공적으로 저장되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('옷 삭제'),
        content: const Text('정말로 이 옷을 옷장에서 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _firebaseService.deleteClothingData(widget.docId);
        if (mounted) {
          Navigator.pop(context); // 상세 페이지 닫기
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('옷 정보 정리', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: _deleteItem,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 이미지 프리뷰
                  Hero(
                    tag: widget.docId,
                    child: Stack(
                      children: [
                        Container(
                          height: 400,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            image: DecorationImage(
                              image: _localImageBytes != null 
                                  ? MemoryImage(_localImageBytes!) as ImageProvider
                                  : NetworkImage(_currentImageUrl),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        if (_isRemovingBg)
                          Container(
                            height: 400,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text(
                                    '누끼 제거 중...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'changeImage_${widget.docId}',
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt),
                                        title: const Text('카메라로 촬영'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _changeImage(ImageSource.camera);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library),
                                        title: const Text('앨범에서 선택'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _changeImage(ImageSource.gallery);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            backgroundColor: Colors.black87,
                            child: const Icon(Icons.edit, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 누끼 제거, 원본 복원 버튼 영역
                  Align(
                    alignment: Alignment.centerRight,
                    child: _isRemovingBg
                        ? const SizedBox.shrink()
                        : Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_removedBgLocalBytes != null ||
                                  (_localImageBytes != null && _localImageBytes != _originalLocalImageBytes) ||
                                  (_localImageBytes == null && _currentImageUrl != _originalImageUrl))
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _localImageBytes = _originalLocalImageBytes;
                                      _currentImageUrl = _originalImageUrl;
                                      _removedBgLocalBytes = null;
                                    });
                                  },
                                  icon: const Icon(Icons.restore),
                                  label: const Text('원본 복원'),
                                ),
                              if (_removedBgLocalBytes == null)
                                TextButton.icon(
                                  onPressed: _removeBackground,
                                  icon: const Icon(Icons.auto_fix_high),
                                  label: const Text('누끼 제거'),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 8),

                  // 활용 통계 섹션 추가
                  _buildOotdUsageSection(),
                  const SizedBox(height: 16),

                  // 2. 정보 수정 폼
                  _buildSectionTitle('기본 정보'),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _inputDecoration('대분류 선택'),
                    items: CategoryData.mainCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val!;
                        _selectedSubCategory = ''; // 소분류 초기화
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  if (CategoryData.getSubCategories(_selectedCategory).isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedSubCategory.isEmpty ? null : _selectedSubCategory,
                      decoration: _inputDecoration('소분류 선택'),
                      items: CategoryData.getSubCategories(_selectedCategory).map((c) => DropdownMenuItem(
                        value: c, 
                        child: Row(
                          children: [
                            Image.asset(
                              CategoryData.getIconPath(c),
                              width: 24,
                              height: 24,
                              color: Colors.black87,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.checkroom, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(c),
                          ],
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedSubCategory = val ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Text('색상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._colorPresets.map((preset) {
                        final String name = preset['name'];
                        final Color color = preset['color'];
                        final isSelected = !_isCustomColor && _selectedColorPreset == name;
                        
                        return ChoiceChip(
                          avatar: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == Colors.white || color == const Color(0xFFFFFFF0) ? Colors.grey[400]! : Colors.transparent,
                              ),
                            ),
                          ),
                          label: Text(name),
                          selected: isSelected,
                          selectedColor: Colors.grey[800],
                          backgroundColor: Colors.grey[200],
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 13),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedColorPreset = name;
                                _isCustomColor = false;
                                _colorController.text = name;
                              });
                            }
                          },
                        );
                      }).toList(),
                      ChoiceChip(
                        label: const Text('직접입력'),
                        selected: _isCustomColor,
                        selectedColor: Colors.grey[800],
                        backgroundColor: Colors.grey[200],
                        labelStyle: TextStyle(color: _isCustomColor ? Colors.white : Colors.black87, fontSize: 13),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _isCustomColor = true;
                              _selectedColorPreset = null;
                              _colorController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_isCustomColor) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _colorController,
                      decoration: _inputDecoration('색상 (예: 크림 베이지)'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _patternController,
                    decoration: _inputDecoration('패턴 (예: 케이블 니트)'),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _materialController,
                    decoration: _inputDecoration('소재 추정 (예: 울 혼방)'),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _fitController,
                    decoration: _inputDecoration('핏 (예: 오버사이즈)'),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _lengthController,
                    decoration: _inputDecoration('기장 (예: 130cm)'),
                  ),
                  const SizedBox(height: 16),
                  
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      return BrandData.filterBrands(textEditingValue.text);
                    },
                    onSelected: (String selection) {
                      _brandController.text = selection;
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      if (textEditingController.text.isEmpty && _brandController.text.isNotEmpty) {
                        textEditingController.text = _brandController.text;
                      }
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        decoration: _inputDecoration('브랜드 (예: 나이키, 자라)'),
                        onChanged: (val) {
                          _brandController.text = val;
                        },
                        onSubmitted: (value) {
                          _brandController.text = value;
                          onFieldSubmitted();
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 48,
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(index);
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                    title: Text(
                                      option,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    hoverColor: Colors.grey[100],
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _sizeController,
                    decoration: _inputDecoration('사이즈 (예: L, 100, 270)'),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _tagsController,
                    decoration: _inputDecoration('태그 (예: #데일리 #여름옷)'),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('나만의 메모'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _memoController,
                    maxLines: 5,
                    decoration: _inputDecoration('이 옷에 대한 특징이나 스타일링 팁을 적어보세요.'),
                  ),
                  
                  const SizedBox(height: 40),

                  // 3. 저장 버튼
                  FilledButton(
                    onPressed: _updateInfo,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('정보 저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // 활용 통계 위젯
  Widget _buildOotdUsageSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getOOTDStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        // 현재 옷이 포함된 OOTD 필터링
        List<Map<String, dynamic>> usedOotds = [];
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          List<dynamic> taggedIds = data['taggedClothesIds'] ?? [];
          if (taggedIds.isEmpty && data['taggedClothes'] != null) {
            taggedIds = (data['taggedClothes'] as List).map((e) => e['id']).toList();
          }
          if (taggedIds.contains(widget.docId)) {
            usedOotds.add(data);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '이 옷을 활용한 OOTD: ${usedOotds.length}번',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: usedOotds.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OotdSelectionScreen(
                              clothingId: widget.docId,
                              clothingItemData: widget.item,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.grey[600], size: 28),
                            const SizedBox(height: 4),
                            Text('+ OOTD 연결', style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    );
                  }

                  final ootd = usedOotds[index - 1];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                      image: DecorationImage(
                        image: NetworkImage(ootd['imageUrl'] ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildWashCareSection(usedOotds.length),
          ],
        );
      },
    );
  }

  // 세탁 케어 리마인더 카드 빌더
  Widget _buildWashCareSection(int totalUsageCount) {
    final int washedSince = totalUsageCount - _lastWashedCount;
    final bool isWashRequired = _washInterval > 0 && washedSince >= _washInterval;

    return Card(
      elevation: 0,
      color: isWashRequired ? Colors.blue[50] : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isWashRequired ? Colors.blueAccent.withOpacity(0.5) : Colors.grey[200]!,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_laundry_service_outlined,
                      color: isWashRequired ? Colors.blueAccent : Colors.black87,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '세탁 & 수명 케어 🧼',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                if (isWashRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '세탁 필요!',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '마지막 세탁 이후 $washedSince회 착용했습니다. (총 $totalUsageCount회 착용)',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _washInterval,
                    decoration: InputDecoration(
                      labelText: '권장 세탁 주기',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('설정 안함')),
                      DropdownMenuItem(value: 3, child: Text('3회 착용 후')),
                      DropdownMenuItem(value: 5, child: Text('5회 착용 후')),
                      DropdownMenuItem(value: 10, child: Text('10회 착용 후')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _washInterval = val ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _lastWashedCount = totalUsageCount;
                    });
                    try {
                      await _firebaseService.updateClothingData(
                        docId: widget.docId,
                        updatedData: {
                          'lastWashedCount': totalUsageCount,
                        },
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('세탁이 완료되어 착용 횟수가 초기화되었습니다.')),
                        );
                      }
                    } catch (e) {
                      debugPrint('🚩 Failed to reset washing count: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: const Text('세탁 완료', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
