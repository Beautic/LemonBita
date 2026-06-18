import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';
import '../utils/categories.dart';
import '../services/bg_removal_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  XFile? _imageFile;
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  bool _isRemovingBg = false;
  final ImagePicker _picker = ImagePicker();
  String _selectedCategory = '상의';
  String _selectedSubCategory = '';
  bool _isLoading = false;
  
  final FirebaseService _firebaseService = FirebaseService();

  String? _selectedColorPreset;
  bool _isCustomColor = false;
  final TextEditingController _colorController = TextEditingController();

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
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  // AI 누끼 가이드 다이얼로그 팝업 정의
  void _showAiGuideDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.auto_fix_high, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text(
                'AI 누끼 제거 가이드',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '옷을 등록할 때 배경을 깨끗이 지우면, 코디 캔버스에서 다른 아이템들과 함께 겹쳐서 꾸미기가 훨씬 수월해집니다.',
                style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 20),
              // Before / After 가상 그래픽 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Before
                  Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Icon(Icons.chair_rounded, size: 24, color: Colors.brown),
                            ),
                            Icon(Icons.checkroom, size: 40, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Before (배경 있음)',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                  // After
                  Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purpleAccent, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.checkroom, size: 48, color: Colors.purpleAccent),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'After (AI 배경 제거)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                '💡 사용법:\n사진을 등록한 후, "누끼 제거하기" 버튼을 누르기만 하면 AI가 자동으로 최적의 배경 제거를 실행합니다.',
                style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 카메라 앱 호출
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 70,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _imageFile = photo;
        _originalImageBytes = bytes;
        _processedImageBytes = bytes;
        _isRemovingBg = false;
      });
      // 사진 선택 즉시 누끼 제거 + 정사각형 꽉 채우기 보정 자동 적용
      await _removeBackground();
    }
  }

  // 갤러리 호출
  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageFile = image;
        _originalImageBytes = bytes;
        _processedImageBytes = bytes;
        _isRemovingBg = false;
      });
      // 사진 선택 즉시 누끼 제거 + 정사각형 꽉 채우기 보정 자동 적용
      await _removeBackground();
    }
  }

  // 누끼 제거 호출
  Future<void> _removeBackground() async {
    if (_processedImageBytes == null) return;
    setState(() => _isRemovingBg = true);
    try {
      final resultBytes = await BgRemovalService.removeBackground(_processedImageBytes!);
      setState(() {
        _processedImageBytes = resultBytes;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('옷장에 추가하기',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 메인 사진 촬영/미리보기 박스
            GestureDetector(
              onTap: _takePhoto,
              child: Container(
                height: 380,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _processedImageBytes != null
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: _processedImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.memory(_processedImageBytes!, fit: BoxFit.contain),
                            if (_isRemovingBg)
                              Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: Colors.white),
                                      SizedBox(height: 16),
                                      Text('누끼 제거 중...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '터치해서 사진 찍기',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 갤러리 전환 및 누끼 제거 버튼
            Row(
              children: [
                TextButton.icon(
                  onPressed: _showAiGuideDialog,
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.purpleAccent),
                  label: const Text('누끼 가이드 💡', style: TextStyle(color: Colors.purpleAccent)),
                ),
                const Spacer(),
                if (_processedImageBytes != null) ...[
                  if (_processedImageBytes == _originalImageBytes)
                    TextButton.icon(
                      onPressed: _isRemovingBg ? null : _removeBackground,
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('누끼 제거하기'),
                    )
                  else
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _processedImageBytes = _originalImageBytes;
                        });
                      },
                      icon: const Icon(Icons.restore),
                      label: const Text('원본 복원하기'),
                    ),
                ],
                TextButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('앨범에서 가져오기'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2. 대분류 선택
            const Text('대분류 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CategoryData.mainCategories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  selectedColor: Colors.black,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _selectedSubCategory = ''; // 소분류 초기화
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // 3. 소분류 선택 (소분류가 있는 경우에만 노출)
            if (CategoryData.getSubCategories(_selectedCategory).isNotEmpty) ...[
              const Text('소분류 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CategoryData.getSubCategories(_selectedCategory).map((subCategory) {
                  final isSelected = _selectedSubCategory == subCategory;
                  return ChoiceChip(
                    avatar: Image.asset(
                      CategoryData.getIconPath(subCategory),
                      width: 24,
                      height: 24,
                      color: isSelected ? Colors.white : Colors.black87,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.checkroom, size: 16),
                    ),
                    label: Text(subCategory),
                    selected: isSelected,
                    selectedColor: Colors.grey[800],
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 13),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedSubCategory = subCategory);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
            
            // 4. 색상 선택
            const Text('색상 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
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
                decoration: InputDecoration(
                  labelText: '색상 (예: 크림 베이지)',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],

            const SizedBox(height: 48),

            // 3. 저장 버튼
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : FilledButton(
                    onPressed: () async {
                      if (_processedImageBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('옷 사진을 먼저 촬영해주세요!')),
                        );
                        return;
                      }

                      if (CategoryData.getSubCategories(_selectedCategory).isNotEmpty && _selectedSubCategory.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('소분류를 선택해주세요!')),
                        );
                        return;
                      }

                      setState(() => _isLoading = true);
                      try {
                        final bytes = _processedImageBytes!;
                        String imageUrl = await _firebaseService.uploadImage(bytes, 'png');

                        await _firebaseService.saveClothingData(
                          imageUrl: imageUrl,
                          category: _selectedCategory,
                          subCategory: _selectedSubCategory,
                          tags: '#$_selectedCategory',
                          color: _colorController.text,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('오류 발생: $e')),
                          );
                        }
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18)
                    ),
                    child: const Text('옷장에 넣기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}
