import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
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

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(suggestedBy != null ? '$suggestedBy님의 추천 코디' : '코디 아이디어', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(
              data['imageUrl'] ?? '',
              width: double.infinity,
              height: MediaQuery.of(context).size.width,
              fit: BoxFit.cover,
            ),
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
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UploadOotdScreen(
                            initialImageUrl: data['imageUrl'],
                            initialTaggedClothes: taggedClothes,
                          ),
                        ),
                      );
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
}
