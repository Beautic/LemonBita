import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../widgets/ootd_interaction_bar.dart';
import 'search_clothes_screen.dart';
import 'ootd_calendar_screen.dart';
import 'upload_ootd_screen.dart';
import 'my_ootd_detail_screen.dart';
import 'planned_ootd_detail_screen.dart';
import 'coordination_canvas_screen.dart';
import 'friends_ootd_feed_screen.dart';

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

  // 코디 아이디어용 상태
  List<QueryDocumentSnapshot> _plannedOotds = [];
  bool _isLoadingPlanned = false;
  bool _hasMorePlanned = true;
  DocumentSnapshot? _lastPlannedDoc;
  String _selectedFolderId = 'all';

  @override
  void initState() {
    super.initState();
    _loadOotds();
    _loadPlannedOotds();
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
      // NOTE: 탭에 따라 각각의 로드 함수를 호출해야 하지만,
      // 간단하게 구현하기 위해 둘 다 호출합니다. (이미 로딩중이거나 hasMore가 아니면 무시됨)
      _loadOotds();
      _loadPlannedOotds();
    }
  }

  Future<void> _loadPlannedOotds({bool refresh = false}) async {
    if (_isLoadingPlanned) return;
    if (refresh) {
      setState(() {
        _plannedOotds.clear();
        _lastPlannedDoc = null;
        _hasMorePlanned = true;
      });
    }

    if (!_hasMorePlanned) return;

    setState(() { _isLoadingPlanned = true; });

    try {
      final newDocs = await _firebaseService.getPlannedOOTDPage(
        folderId: _selectedFolderId,
        lastDoc: _lastPlannedDoc,
        limit: 10,
      );
      setState(() {
        if (newDocs.length < 10) {
          _hasMorePlanned = false;
        }
        if (newDocs.isNotEmpty) {
          _lastPlannedDoc = newDocs.last;
          _plannedOotds.addAll(newDocs);
        }
        _isLoadingPlanned = false;
      });
    } catch (e) {
      setState(() { _isLoadingPlanned = false; });
      debugPrint("Planned OOTD 로드 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: '내 OOTD'),
              Tab(text: '친구 피드'),
              Tab(text: '코디 아이디어'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: () => _loadOotds(refresh: true),
              color: Colors.black,
              child: _buildBody(),
            ),
            const FriendsOotdFeedScreen(),
            _buildPlannedBody(),
          ],
        ),
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

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: _ootds.length,
      itemBuilder: (context, index) {
        final doc = _ootds[index];
        final item = doc.data() as Map<String, dynamic>;
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyOotdDetailScreen(ootdId: doc.id)),
            ).then((deleted) {
              if (deleted == true) {
                _loadOotds(refresh: true);
              }
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item['imageUrl'] ?? '',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported, color: Colors.grey)),
              ),
              if ((item['taggedClothes'] as List?)?.isNotEmpty == true)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.style, color: Colors.white, size: 16),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlannedBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFolderBar(),
        Divider(height: 1, color: Colors.grey[200]),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadPlannedOotds(refresh: true),
            color: Colors.black,
            child: _buildPlannedGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderBar() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firebaseService.getPlannedFoldersStream(),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? [];
        
        return Container(
          height: 60,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildFolderChip(id: 'all', name: '전체'),
              const SizedBox(width: 8),
              _buildFolderChip(id: 'unclassified', name: '미분류'),
              const SizedBox(width: 8),
              ...folders.map((folder) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildFolderChip(
                  id: folder['id'] as String,
                  name: folder['name'] as String,
                  isDeletable: true,
                ),
              )),
              IconButton(
                icon: Icon(
                  Theme.of(context).platform == TargetPlatform.iOS
                      ? CupertinoIcons.folder_badge_plus
                      : Icons.create_new_folder_outlined,
                  color: Colors.black54,
                  size: 20,
                ),
                onPressed: _showCreateFolderDialog,
                tooltip: '폴더 만들기',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFolderChip({required String id, required String name, bool isDeletable = false}) {
    final isSelected = _selectedFolderId == id;
    return GestureDetector(
      onTap: () {
        if (_selectedFolderId != id) {
          setState(() {
            _selectedFolderId = id;
          });
          _loadPlannedOotds(refresh: true);
        }
      },
      onLongPress: isDeletable ? () => _showFolderManageOptions(id, name) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDeletable)
              Icon(Icons.folder_outlined, size: 14, color: isSelected ? Colors.white70 : Colors.grey),
            if (isDeletable)
              const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('새 폴더 만들기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '폴더 이름을 입력하세요 (예: 유럽여행)',
              hintStyle: TextStyle(fontSize: 14),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    await _firebaseService.createPlannedFolder(name);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더가 생성되었습니다.')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('폴더 생성 실패: $e')));
                  }
                }
              },
              child: const Text('만들기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showFolderManageOptions(String id, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text('"$name" 폴더 관리', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.black87),
                title: const Text('폴더 이름 수정'),
                onTap: () {
                  Navigator.pop(context);
                  _showUpdateFolderDialog(id, name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('폴더 삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteFolderDialog(id, name);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateFolderDialog(String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('폴더 이름 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '새 이름을 입력하세요',
              hintStyle: TextStyle(fontSize: 14),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty && name != currentName) {
                  Navigator.pop(context);
                  try {
                    await _firebaseService.updatePlannedFolder(id, name);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더 이름이 수정되었습니다.')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이름 수정 실패: $e')));
                  }
                }
              },
              child: const Text('수정', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteFolderDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('폴더 삭제', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text('"$name" 폴더를 삭제하시겠습니까?\n폴더 내의 코디 아이디어는 삭제되지 않고 미분류로 이동합니다.', style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _firebaseService.deletePlannedFolder(id);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더가 삭제되었습니다.')));
                  if (_selectedFolderId == id) {
                    setState(() {
                      _selectedFolderId = 'all';
                    });
                    _loadPlannedOotds(refresh: true);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('폴더 삭제 실패: $e')));
                }
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showFolderMoveDialog(String ootdId, String? currentFolderId) {
    showDialog(
      context: context,
      builder: (context) {
        String tempSelectedId = currentFolderId ?? 'unclassified';
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('폴더 이동', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firebaseService.getPlannedFoldersStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.black));
                    }
                    
                    final folders = snapshot.data!;
                    
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        RadioListTile<String>(
                          title: const Text('미분류'),
                          value: 'unclassified',
                          groupValue: tempSelectedId,
                          activeColor: Colors.black,
                          onChanged: (val) {
                            setDialogState(() {
                              tempSelectedId = val!;
                            });
                          },
                        ),
                        ...folders.map((folder) {
                          return RadioListTile<String>(
                            title: Text(folder['name'] as String),
                            value: folder['id'] as String,
                            groupValue: tempSelectedId,
                            activeColor: Colors.black,
                            onChanged: (val) {
                              setDialogState(() {
                                tempSelectedId = val!;
                              });
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final targetFolderId = tempSelectedId == 'unclassified' ? null : tempSelectedId;
                    try {
                      await _firebaseService.updatePlannedOotdFolder(ootdId, targetFolderId);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더가 변경되었습니다.')));
                      _loadPlannedOotds(refresh: true);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('폴더 변경 실패: $e')));
                    }
                  },
                  child: const Text('이동', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlannedGrid() {
    if (_plannedOotds.isEmpty && _isLoadingPlanned) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (_plannedOotds.isEmpty && !_isLoadingPlanned) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('저장된 코디 아이디어가 없습니다.', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _plannedOotds.length,
      itemBuilder: (context, index) {
        final doc = _plannedOotds[index];
        final data = doc.data() as Map<String, dynamic>;
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PlannedOotdDetailScreen(plannedOotdId: doc.id)),
            ).then((_) => _loadPlannedOotds(refresh: true));
          },
          onLongPress: () => _showFolderMoveDialog(doc.id, data['folderId']),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(data['imageUrl'] ?? ''),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (data['suggestedBy'] != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                    child: Text(
                      '💡 by ${data['suggestedBy']}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showPlannedOotdDetail(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  data['imageUrl'] ?? '',
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _firebaseService.deletePlannedOOTDData(docId);
                        _loadPlannedOotds(refresh: true);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('삭제', style: TextStyle(color: Colors.red)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        List<dynamic> canvasItems = data['canvasItems'] ?? data['taggedClothes'] ?? [];
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CoordinationCanvasScreen(
                              editDocId: docId,
                              initialCanvasItems: canvasItems,
                            ),
                          ),
                        ).then((_) {
                          _loadPlannedOotds(refresh: true);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.edit),
                      label: const Text('코디 수정'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        List<dynamic> tagged = data['taggedClothes'] ?? [];
                        final tagsSet = tagged.map((e) => e['id'] as String).toSet();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UploadOotdScreen(
                              initialImageUrl: data['imageUrl'],
                              initialTaggedClothes: tagsSet,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text('OOTD로 등록'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
