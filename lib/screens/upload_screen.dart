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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_processedImageBytes != null)
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
