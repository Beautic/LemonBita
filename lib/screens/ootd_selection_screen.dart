import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class OotdSelectionScreen extends StatefulWidget {
  final String clothingId;
  final Map<String, dynamic> clothingItemData;

  const OotdSelectionScreen({
    super.key,
    required this.clothingId,
    required this.clothingItemData,
  });

  @override
  State<OotdSelectionScreen> createState() => _OotdSelectionScreenState();
}

class _OotdSelectionScreenState extends State<OotdSelectionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  List<QueryDocumentSnapshot> _allOotds = [];
  final Set<String> _initialSelectedIds = {};
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchOotds();
  }

  Future<void> _fetchOotds() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ootds')
          .where('userId', isEqualTo: _firebaseService.currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      final List<QueryDocumentSnapshot> ootds = snapshot.docs;
      
      // 기존에 태그된 OOTD 식별
      for (var doc in ootds) {
        final data = doc.data() as Map<String, dynamic>;
        List<dynamic> taggedIds = data['taggedClothesIds'] ?? [];
        if (taggedIds.isEmpty && data['taggedClothes'] != null) {
          taggedIds = (data['taggedClothes'] as List).map((e) => e['id']).toList();
        }
        if (taggedIds.contains(widget.clothingId)) {
          _initialSelectedIds.add(doc.id);
          _selectedIds.add(doc.id);
        }
      }

      setState(() {
        _allOotds = ootds;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('OOTD 목록 불러오기 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSelection() async {
    setState(() => _isSaving = true);
    try {
      await _firebaseService.updateOOTDClothesTags(
        clothingId: widget.clothingId,
        clothingItemData: widget.clothingItemData,
        selectedOotdIds: _selectedIds.toList(),
        originalOotdIds: _initialSelectedIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 업데이트 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기존 OOTD와 연결하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSelection,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Text('완료', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _allOotds.isEmpty
              ? const Center(child: Text('등록된 OOTD가 없습니다.', style: TextStyle(color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _allOotds.length,
                  itemBuilder: (context, index) {
                    final doc = _allOotds[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedIds.contains(doc.id);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(doc.id);
                          } else {
                            _selectedIds.add(doc.id);
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.black : Colors.transparent,
                                width: 3,
                              ),
                              image: DecorationImage(
                                image: NetworkImage(data['imageUrl'] ?? ''),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 16, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
