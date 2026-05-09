import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../utils/categories.dart';
import '../services/bg_removal_service.dart';
import 'dart:typed_data';
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
  late String _currentImageUrl;
  late String _originalImageUrl;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.item['imageUrl'];
    _originalImageUrl = widget.item['imageUrl'];
    _brandController = TextEditingController(text: widget.item['brand'] ?? '');
    _sizeController = TextEditingController(text: widget.item['size'] ?? '');
    _tagsController = TextEditingController(text: widget.item['tags'] ?? '');
    _memoController = TextEditingController(text: widget.item['memo'] ?? '');
    _colorController = TextEditingController(text: widget.item['color'] ?? '');
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

  Future<void> _removeBackground() async {
    setState(() => _isRemovingBg = true);
    try {
      final originalBytes = await _firebaseService.downloadImage(_currentImageUrl);
      if (originalBytes == null) {
        throw Exception('이미지를 불러올 수 없습니다.');
      }
      // 저장된 PNG는 알파 채널이 있어 라이브러리 입력으로 부적합 → 흰배경 JPEG로 평탄화
      final flatBytes = await BgRemovalService.flattenImageToJpeg(originalBytes);
      final resultBytes = await BgRemovalService.removeBackground(flatBytes);
      String newImageUrl = await _firebaseService.uploadImage(resultBytes, 'png');

      setState(() {
        _currentImageUrl = newImageUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('누끼가 성공적으로 제거되었습니다.')),
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
      await _firebaseService.updateClothingData(
        docId: widget.docId,
        updatedData: {
          'imageUrl': _currentImageUrl,
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
                    child: Container(
                      height: 400,
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
                          image: NetworkImage(_currentImageUrl),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 누끼 제거 및 원본 복원 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: _isRemovingBg
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : _currentImageUrl == _originalImageUrl
                            ? TextButton.icon(
                                onPressed: _removeBackground,
                                icon: const Icon(Icons.auto_fix_high),
                                label: const Text('현재 이미지 누끼 제거하기'),
                              )
                            : TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _currentImageUrl = _originalImageUrl;
                                  });
                                },
                                icon: const Icon(Icons.restore),
                                label: const Text('원본 이미지로 복원하기'),
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
                      onChanged: (val) => setState(() => _selectedSubCategory = val ?? ''),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  TextField(
                    controller: _colorController,
                    decoration: _inputDecoration('색상 (예: 크림 베이지)'),
                  ),
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
                  
                  TextField(
                    controller: _brandController,
                    decoration: _inputDecoration('브랜드 (예: 나이키, 자라)'),
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

        if (usedOotds.isEmpty) return const SizedBox.shrink();

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
                itemCount: usedOotds.length,
                itemBuilder: (context, index) {
                  final ootd = usedOotds[index];
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
          ],
        );
      },
    );
  }
}
