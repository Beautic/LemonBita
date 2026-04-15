import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';

class UploadScreen extends StatefulWidget {
  final FirebaseService? firebaseService;
  const UploadScreen({super.key, this.firebaseService});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String _selectedCategory = '상의';
  bool _isLoading = false;

  late final FirebaseService _firebaseService;

  final List<String> _categories = ['상의', '하의', '아우터', '신발', '액세서리', '기타'];

  @override
  void initState() {
    super.initState();
    _firebaseService = widget.firebaseService ?? FirebaseService();
  }

  // 카메라 앱 호출
  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080, // 무료 티어 용량 절약을 위한 리사이징
      maxHeight: 1080,
      imageQuality: 70,
    );
    if (photo != null) {
      setState(() {
        _imageFile = File(photo.path);
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
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('옷장에 추가하기', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    color: _imageFile != null
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: _imageFile != null ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ] : null,
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.file(_imageFile!, fit: BoxFit.cover),
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
                          const SizedBox(height: 8),
                          Text(
                            '옷의 정면이 잘 보이게 찍어주세요',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // 갤러리 전환 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('앨범에서 가져오기'),
              ),
            ),

            const SizedBox(height: 24),

            // 2. 카테고리 선택 칩
            Text(
              '카테고리 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 48),

            // 3. 최종 저장(업로드) 버튼
            _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FilledButton(
                  onPressed: () async {
                    if (_imageFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('옷 사진을 먼저 촬영해주세요!'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    setState(() => _isLoading = true);

                    try {
                      // 1. Storage에 이미지 업로드
                      String imageUrl = await _firebaseService.uploadImage(_imageFile!);

                      // 2. Firestore에 데이터 저장
                      await _firebaseService.saveClothingData(
                        imageUrl: imageUrl,
                        category: _selectedCategory,
                        tags: '#$_selectedCategory', // 간단한 자동 태그
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('옷장에 성공적으로 보관되었습니다!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('오류 발생: $e'),
                            backgroundColor: Theme.of(context).colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '옷장에 넣기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
