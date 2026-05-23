import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../widgets/ootd_post_widget.dart';

class SingleOotdScreen extends StatefulWidget {
  final String ootdId;
  const SingleOotdScreen({super.key, required this.ootdId});

  @override
  State<SingleOotdScreen> createState() => _SingleOotdScreenState();
}

class _SingleOotdScreenState extends State<SingleOotdScreen> {
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
      final doc = await FirebaseFirestore.instance.collection('ootds').doc(widget.ootdId).get();
      if (doc.exists && mounted) {
        setState(() {
          _data = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시글을 찾을 수 없습니다.')));
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
        body: const Center(child: Text('삭제되었거나 존재하지 않는 게시글입니다.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('게시물', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: OotdPostWidget(
          ootdId: widget.ootdId,
          data: _data!,
          firebaseService: _firebaseService,
        ),
      ),
    );
  }
}
