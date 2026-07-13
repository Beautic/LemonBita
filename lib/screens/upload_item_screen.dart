import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/bg_removal_service.dart';
import '../theme/app_theme.dart';

class UploadItemScreen extends StatefulWidget {
  const UploadItemScreen({super.key});

  @override
  State<UploadItemScreen> createState() => _UploadItemScreenState();
}

class _UploadItemScreenState extends State<UploadItemScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  XFile? _imageFile;
  Uint8List? _originalImageBytes;
  Uint8List? _processedImageBytes;
  bool _isRemovingBg = false;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _acquiredDateController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String _selectedCategory = '보드게임';
  final List<String> _categories = ['보드게임', '피규어', '향수', 'LP', '기타'];

  List<String> _selectedFolderIds = [];
  bool _isFavorite = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _acquiredDateController.dispose();
    _priceController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // 갤러리/카메라 이미지 선택
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageFile = picked;
          _originalImageBytes = bytes;
          _processedImageBytes = null;
        });
        _showAiGuideDialog();
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
    }
  }

  // AI 누끼 가이드 다이얼로그
  void _showAiGuideDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Row(
            children: [
              Icon(Icons.auto_fix_high, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text('AI 누끼 제거 가이드', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            '소장품 이미지를 등록할 때 배경을 지우면 격자 인벤토리에 보관하거나 상세히 볼 때 훨씬 예쁘고 수집품 본연의 비주얼이 강조됩니다.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('원본 사용', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _removeBackground();
              },
              child: const Text('배경 제거하기', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 백그라운드 제거 기동
  Future<void> _removeBackground() async {
    if (_originalImageBytes == null) return;
    setState(() {
      _isRemovingBg = true;
    });

    try {
      final processed = await BgRemovalService.removeBackground(_originalImageBytes!);
      setState(() {
        _processedImageBytes = processed;
        _isRemovingBg = false;
      });
    } catch (e) {
      debugPrint("BG removal error: $e");
      setState(() {
        _isRemovingBg = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('배경 제거에 실패했습니다: $e')),
      );
    }
  }

  // 소장품 데이터 최종 등록
  Future<void> _uploadItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이템 이름을 입력해 주세요.')),
      );
      return;
    }

    final activeBytes = _processedImageBytes ?? _originalImageBytes;
    if (activeBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이템 이미지를 등록해 주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 이미지 Storage 업로드
      final imageUrl = await _firebaseService.uploadImage(activeBytes, 'png');

      // 2. 가격 파싱
      final int price = int.tryParse(_priceController.text.replaceAll(',', '').trim()) ?? 0;

      // 3. Firestore 삽입
      await _firebaseService.addItemData(
        imageUrl: imageUrl,
        category: _selectedCategory,
        folderId: _selectedFolderIds.isNotEmpty ? _selectedFolderIds.first : '',
        folderIds: _selectedFolderIds,
        brand: _brandController.text.trim(),
        name: name,
        acquiredDate: _acquiredDateController.text.trim(),
        price: price,
        memo: _memoController.text.trim(),
        isFavorite: _isFavorite,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새 아이템이 성공적으로 등록되었습니다.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Item upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('아이템 등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeImageBytes = _processedImageBytes ?? _originalImageBytes;

    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('새 아이템 추가', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _uploadItem,
              child: const Text('등록', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 등록 카드 영역
            Center(
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (context) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library_outlined),
                            title: const Text('갤러리에서 선택'),
                            onTap: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.gallery);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt_outlined),
                            title: const Text('카메라로 촬영'),
                            onTap: () {
                              Navigator.pop(context);
                              _pickImage(ImageSource.camera);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.slot,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: _isRemovingBg
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: AppColors.ink),
                            SizedBox(height: 12),
                            Text('배경 제거하는 중...', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        )
                      : activeImageBytes != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  child: Image.memory(activeImageBytes, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                                    child: const Text('변경', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                                if (_processedImageBytes != null)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.purple.withOpacity(0.8), borderRadius: BorderRadius.circular(6)),
                                      child: const Text('AI 배경제거됨', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.muted),
                                SizedBox(height: 8),
                                Text('이미지 등록', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 필수 인풋 항목들
            const Text('아이템 명칭 *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '소장품의 이름을 입력하세요 (예: 할리갈리, 렛서나리 피규어)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),

            const Text('카테고리 *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : AppColors.ink)),
                  selected: isSelected,
                  selectedColor: AppColors.ink,
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button), side: BorderSide(color: isSelected ? AppColors.ink : AppColors.line)),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    }
                  },
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // 가방(폴더) 선택 영역
            const Text('보관할 가방 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firebaseService.getItemFoldersStream(),
              builder: (context, snapshot) {
                final folders = snapshot.data ?? [];

                if (folders.isEmpty) {
                  return const Text('생성된 아이템 가방이 없습니다. 가방을 만들어 아이템을 분류해 보세요.', style: TextStyle(fontSize: 12, color: AppColors.muted));
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: folders.map((folder) {
                    final isSelected = _selectedFolderIds.contains(folder['id']);
                    return ChoiceChip(
                      label: Text(folder['name'] ?? '', style: TextStyle(color: isSelected ? Colors.white : AppColors.ink)),
                      selected: isSelected,
                      selectedColor: AppColors.ink,
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button), side: BorderSide(color: isSelected ? AppColors.ink : AppColors.line)),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedFolderIds = [folder['id']!];
                          } else {
                            _selectedFolderIds.remove(folder['id']);
                          }
                        });
                      },
                      showCheckmark: false,
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),

            // 브랜드/제조사
            const Text('제조사 / 브랜드', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _brandController,
              decoration: InputDecoration(
                hintText: '제작사나 브랜드를 적어주세요 (예: 보드엠, 반다이, 샤넬)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),

            // 소장/취득일
            const Text('소장 시작일', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _acquiredDateController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: '날짜를 고르세요',
                suffixIcon: const Icon(Icons.calendar_month, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button), borderSide: BorderSide.none),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: AppColors.ink, onPrimary: Colors.white, onSurface: AppColors.ink),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _acquiredDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  });
                }
              },
            ),
            const SizedBox(height: 18),

            // 가격 / 가치
            const Text('구입 가격 / 소장 가치 (원)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '금액을 입력하세요 (예: 25000)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),

            // 간단 메모
            const Text('메모', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '기념할 점이나 상세 상태를 메모해 주세요.',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 18),

            // 즐겨찾기 설정 (희귀도)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('특별 소장품 설정 ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('즐겨찾기 지정 시 슬롯에 액센트 노치가 표시됩니다.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
                Switch(
                  activeColor: AppColors.accent,
                  value: _isFavorite,
                  onChanged: (val) {
                    setState(() {
                      _isFavorite = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
