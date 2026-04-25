import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firebase_service.dart';

class UploadOotdScreen extends StatefulWidget {
  const UploadOotdScreen({super.key});

  @override
  State<UploadOotdScreen> createState() => _UploadOotdScreenState();
}

class _UploadOotdScreenState extends State<UploadOotdScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _descController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageExtension;
  bool _isUploading = false;

  // 태그된 옷들의 문서 ID 목록
  final Set<String> _selectedClothesIds = {};
  
  // 전체 옷 목록을 메모리에 들고 있기 위한 변수
  List<QueryDocumentSnapshot> _allClothes = [];
  bool _isLoadingClothes = true;

  @override
  void initState() {
    super.initState();
    _fetchClothes();
  }

  Future<void> _fetchClothes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('clothes')
          .where('userId', isEqualTo: _firebaseService.currentUserId)
          .orderBy('createdAt', descending: true)
          .get();
      setState(() {
        _allClothes = snapshot.docs;
        _isLoadingClothes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingClothes = false;
      });
      debugPrint('옷 목록 불러오기 실패: $e');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      setState(() {
        _imageBytes = bytes;
        _imageExtension = ext;
      });
    }
  }

  Future<void> _uploadOOTD() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OOTD 사진을 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. 이미지 업로드
      String imageUrl = await _firebaseService.uploadImage(
        _imageBytes!,
        _imageExtension ?? 'jpg',
      );

      // 2. 태그된 옷 데이터 구성
      List<Map<String, dynamic>> taggedClothes = [];
      for (var doc in _allClothes) {
        if (_selectedClothesIds.contains(doc.id)) {
          final data = doc.data() as Map<String, dynamic>;
          String title = '${data['color'] ?? ''} ${data['pattern'] ?? ''}'.trim();
          if (title.isEmpty) title = data['brand'] ?? '';
          if (title.isEmpty) title = data['category'] ?? '옷 정보 없음';

          taggedClothes.add({
            'id': doc.id,
            'imageUrl': data['imageUrl'],
            'title': title,
          });
        }
      }

      // 3. Firestore 저장
      await _firebaseService.saveOOTDData(
        imageUrl: imageUrl,
        description: _descController.text.trim(),
        taggedClothes: taggedClothes,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OOTD가 성공적으로 업로드되었습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('새로운 OOTD', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _uploadOOTD,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('공유', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 이미지 선택 영역
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 350,
                color: Colors.grey[100],
                child: _imageBytes != null
                    ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('OOTD 사진 선택', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),

            // 2. 코멘트 입력
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '오늘의 코디에 대해 이야기해주세요...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // 3. 옷 태깅 영역
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Text('이 코디에 쓰인 옷 태그하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${_selectedClothesIds.length}개 선택됨', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),

            // 옷 목록 가로 스크롤
            if (_isLoadingClothes)
              const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.black)))
            else if (_allClothes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('옷장에 등록된 옷이 없습니다.', style: TextStyle(color: Colors.grey[500])),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _allClothes.length,
                  itemBuilder: (context, index) {
                    final doc = _allClothes[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedClothesIds.contains(doc.id);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedClothesIds.remove(doc.id);
                          } else {
                            _selectedClothesIds.add(doc.id);
                          }
                        });
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected ? Colors.black : Colors.transparent,
                                      width: 3,
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(item['imageUrl'] ?? ''),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['category'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
