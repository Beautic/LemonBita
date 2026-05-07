import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import 'search_clothes_screen.dart';
import 'ootd_calendar_screen.dart';

class OotdScreen extends StatefulWidget {
  const OotdScreen({super.key});

  @override
  State<OotdScreen> createState() => _OotdScreenState();
}

class _OotdScreenState extends State<OotdScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();
  
  List<QueryDocumentSnapshot> _ootds = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadOotds();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOotds({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _ootds.clear();
        _lastDocument = null;
        _hasMore = true;
      });
    }

    if (!_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final newDocs = await _firebaseService.getOOTDPage(lastDoc: _lastDocument, limit: 10);
      
      setState(() {
        if (newDocs.length < 10) {
          _hasMore = false;
        }
        if (newDocs.isNotEmpty) {
          _lastDocument = newDocs.last;
          _ootds.addAll(newDocs);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // 혹시 복합 인덱스 에러가 날 수 있음
      debugPrint("OOTD 로드 에러: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadOotds();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'OOTD',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OotdCalendarScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadOotds(refresh: true),
        color: Colors.black,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_ootds.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (_ootds.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('첫 번째 OOTD를 기록해보세요!', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: _ootds.length + (_hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 32, thickness: 8, color: Color(0xFFF5F5F5)),
      itemBuilder: (context, index) {
        if (index == _ootds.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }

        final doc = _ootds[index];
        final item = doc.data() as Map<String, dynamic>;
        return _buildOotdPost(doc.id, item);
      },
    );
  }

  Widget _buildOotdPost(String docId, Map<String, dynamic> item) {
    // Timestamp 변환
    String dateStr = '';
    if (item['createdAt'] != null) {
      final dt = (item['createdAt'] as Timestamp).toDate();
      dateStr = DateFormat('yyyy년 MM월 dd일').format(dt);
    }

    // 태그된 옷 파싱
    List<dynamic> taggedClothes = item['taggedClothes'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 헤더 (날짜)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'My Daily Look',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month, size: 20, color: Colors.black54),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final initialDate = item['createdAt'] != null ? (item['createdAt'] as Timestamp).toDate() : DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.black,
                            onPrimary: Colors.white,
                            onSurface: Colors.black,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null && !DateUtils.isSameDay(picked, initialDate)) {
                    await _firebaseService.updateOOTDDate(docId, picked);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('날짜가 수정되었습니다.')),
                      );
                    }
                    _loadOotds(refresh: true);
                  }
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.black54),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final initialIds = taggedClothes.map((cloth) => cloth['id'] as String).toSet();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchClothesScreen(
                        isSelectionMode: true,
                        initialSelectedIds: initialIds,
                      ),
                    ),
                  );

                  if (result != null && result is List<Map<String, dynamic>>) {
                    await _firebaseService.updateOOTDTags(docId, result);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('태그가 수정되었습니다.')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),

        // 2. 이미지
        Container(
          width: double.infinity,
          height: 400,
          color: Colors.grey[100],
          child: Image.network(
            item['imageUrl'] ?? '',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),

        // 3. 코멘트 영역
        if ((item['description'] ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              item['description'],
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),

        // 4. 태그된 옷 영역
        if (taggedClothes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sell, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('이 OOTD에 입은 옷', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: taggedClothes.length,
                    itemBuilder: (context, index) {
                      final cloth = taggedClothes[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(cloth['imageUrl'] ?? ''),
                              backgroundColor: Colors.grey[200],
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Text(
                                cloth['title'] ?? '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

