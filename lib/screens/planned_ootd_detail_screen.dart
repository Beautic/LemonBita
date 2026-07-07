import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../widgets/ootd_interaction_bar.dart';
import 'coordination_canvas_screen.dart';
import 'upload_ootd_screen.dart';

class PlannedOotdDetailScreen extends StatefulWidget {
  final String plannedOotdId;
  const PlannedOotdDetailScreen({super.key, required this.plannedOotdId});

  @override
  State<PlannedOotdDetailScreen> createState() => _PlannedOotdDetailScreenState();
}

class _PlannedOotdDetailScreenState extends State<PlannedOotdDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _data;
  bool _isLoading = true;

  // 피드백 입력을 위한 멤버 변수 추가
  double _selectedRating = 5.0;
  late TextEditingController _feedbackController;
  final FocusNode _feedbackFocusNode = FocusNode();
  
  // 피드백 수정 상태 관리 변수 추가
  bool _isEditingFeedback = false;

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController();
    _loadData();

    // 포커스가 잡힐 때 텍스트 필드가 잘 보이도록 보정 스크롤
    _feedbackFocusNode.addListener(() {
      if (_feedbackFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Scrollable.ensureVisible(
              _feedbackFocusNode.context!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _feedbackFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('planned_ootds').doc(widget.plannedOotdId).get();
      if (doc.exists && mounted) {
        setState(() {
          _data = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('코디를 찾을 수 없습니다.')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFolderMoveDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String? currentFolderId = _data!['folderId'];
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
                      await _firebaseService.updatePlannedOotdFolder(widget.plannedOotdId, targetFolderId);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더가 변경되었습니다.')));
                      _loadData();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(),
        body: const Center(child: Text('삭제되었거나 존재하지 않는 코디입니다.')),
      );
    }

    final data = _data!;
    final suggestedBy = data['suggestedBy'];

    // 키보드가 활성화되었는지 감지
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // 키보드가 켜지면 이미지 높이를 줄여 입력 공간 확보
    final imageHeight = isKeyboardOpen 
        ? MediaQuery.of(context).size.width * 0.45 
        : MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(suggestedBy != null ? '$suggestedBy님의 추천 코디' : '코디 아이디어', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.black87),
            onPressed: _showFolderMoveDialog,
            tooltip: '폴더 이동',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: double.infinity,
              height: imageHeight,
              child: Image.network(
                data['imageUrl'] ?? '',
                fit: BoxFit.contain,
              ),
            ),
            if (suggestedBy != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                color: Colors.white,
                child: Text(
                  '💡 $suggestedBy님이 추천해준 코디예요',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            Container(
              color: Colors.white,
              child: OotdInteractionBar(
                collectionName: 'planned_ootds',
                ootdId: widget.plannedOotdId,
                ownerId: data['userId'] ?? '',
                likedBy: data['likedBy'] ?? [],
                commentCount: data['commentCount'] ?? 0,
                firebaseService: _firebaseService,
                onLikeToggled: (newLikedBy) {
                  setState(() {
                    _data!['likedBy'] = newLikedBy;
                  });
                },
              ),
            ),
            _buildFeedbackSection(),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await _firebaseService.deletePlannedOOTDData(widget.plannedOotdId);
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('삭제', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      List<dynamic> canvasItems = data['canvasItems'] ?? data['taggedClothes'] ?? [];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CoordinationCanvasScreen(
                            editDocId: widget.plannedOotdId,
                            initialCanvasItems: canvasItems,
                          ),
                        ),
                      ).then((_) => _loadData());
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
                      List<dynamic> taggedClothes = data['taggedClothes'] ?? [];
                      if (data['canvasItems'] != null) {
                        taggedClothes = (data['canvasItems'] as List).map((e) => {
                          'id': e['id'],
                          'imageUrl': e['imageUrl'],
                        }).toList();
                      }
                      
                      Set<String> taggedIds = taggedClothes.map((e) => e['id'] as String).toSet();
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UploadOotdScreen(
                            initialImageUrl: data['imageUrl'],
                            initialTaggedClothes: taggedIds,
                          ),
                        ),
                      ).then((uploaded) {
                        if (uploaded == true && mounted) {
                          Navigator.pop(context, true);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('이 코디 입기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 피드백 등록 및 뷰 섹션 추가
  Widget _buildFeedbackSection() {
    final data = _data!;
    final suggestedBy = data['suggestedBy'];
    final suggestedById = data['suggestedById'];
    final currentUserId = _firebaseService.currentUserId;

    if (suggestedBy == null || data['userId'] != currentUserId) {
      return const SizedBox.shrink();
    }

    final double currentRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final String currentFeedback = data['feedback'] ?? '';

    // 피드백이 존재하고 수정 모드가 아닌 경우 -> 보낸 피드백 카드 노출
    if (currentRating > 0.0 && !_isEditingFeedback) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.feedback_outlined, color: Colors.purpleAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$suggestedBy님에게 보낸 피드백 💬',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                    ),
                  ],
                ),
                // 수정 아이콘 버튼 추가 (호환성 높은 Icons.edit로 변경)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.purple, size: 18),
                  onPressed: () {
                    setState(() {
                      _isEditingFeedback = true;
                      _selectedRating = currentRating;
                      _feedbackController.text = currentFeedback;
                    });
                    // 입력 포커스 활성화
                    _feedbackFocusNode.requestFocus();
                  },
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  tooltip: '피드백 수정하기',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < currentRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 20,
                );
              }),
            ),
            if (currentFeedback.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '"$currentFeedback"',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
              ),
            ],
          ],
        ),
      );
    }

    // 피드백이 없거나 수정 모드인 경우 -> 입력/수정 폼 노출
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditingFeedback 
                ? '💡 $suggestedBy님에게 보낸 피드백 수정하기' 
                : '💡 $suggestedBy님의 코디 추천은 어떠셨나요?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final score = index + 1.0;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRating = score;
                  });
                },
                child: Icon(
                  _selectedRating >= score ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 28,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _feedbackController,
            focusNode: _feedbackFocusNode,
            style: const TextStyle(fontSize: 13),
            onTapOutside: (event) {
              // 외부 터치나 스크롤 터치 시 포커스(커서)가 자동으로 꺼지지 않도록 방어
            },
            decoration: InputDecoration(
              hintText: '친구에게 피드백 한 줄 남기기 (예: 오늘 입을게!)',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_isEditingFeedback) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditingFeedback = false;
                        _feedbackController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black26),
                      minimumSize: const Size.fromHeight(38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('취소', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () async {
                    final text = _feedbackController.text.trim();
                    try {
                      await FirebaseFirestore.instance.collection('planned_ootds').doc(widget.plannedOotdId).update({
                        'rating': _selectedRating,
                        'feedback': text,
                        'feedbackAt': FieldValue.serverTimestamp(),
                      });

                      if (suggestedById != null) {
                        final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
                        final myNickname = myDoc.data()?['nickname'] ?? '친구';
                        
                        await _firebaseService.sendNotification(
                          recipientId: suggestedById,
                          type: 'outfit_feedback',
                          message: '$myNickname님이 내 코디 추천에 피드백을 남겼습니다!',
                          targetId: widget.plannedOotdId,
                        );
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('피드백이 전달되었습니다.')));
                        setState(() {
                          _isEditingFeedback = false;
                        });
                        _loadData();
                      }
                    } catch (e) {
                      debugPrint('🚩 Failed to submit feedback: $e');
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _isEditingFeedback ? '수정 완료 💬' : '피드백 보내기 💬', 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
