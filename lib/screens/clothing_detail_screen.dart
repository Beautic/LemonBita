import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

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
  late String _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = ['상의', '하의', '아우터', '신발', '액세서리', '기타'];

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.item['brand'] ?? '');
    _sizeController = TextEditingController(text: widget.item['size'] ?? '');
    _tagsController = TextEditingController(text: widget.item['tags'] ?? '');
    _memoController = TextEditingController(text: widget.item['memo'] ?? '');
    _selectedCategory = widget.item['category'] ?? '상의';
  }

  @override
  void dispose() {
    _brandController.dispose();
    _sizeController.dispose();
    _tagsController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _updateInfo() async {
    setState(() => _isLoading = true);
    try {
      await _firebaseService.updateClothingData(
        docId: widget.docId,
        updatedData: {
          'brand': _brandController.text,
          'size': _sizeController.text,
          'tags': _tagsController.text,
          'memo': _memoController.text,
          'category': _selectedCategory,
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
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        image: DecorationImage(
                          image: NetworkImage(widget.item['imageUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 2. 정보 수정 폼
                  _buildSectionTitle('기본 정보'),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: _inputDecoration('카테고리 선택'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val!),
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
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('정보 저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}
