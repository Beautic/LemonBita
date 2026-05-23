import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../widgets/ootd_post_widget.dart';

class FriendsOotdFeedScreen extends StatefulWidget {
  const FriendsOotdFeedScreen({super.key});

  @override
  State<FriendsOotdFeedScreen> createState() => _FriendsOotdFeedScreenState();
}

class _FriendsOotdFeedScreenState extends State<FriendsOotdFeedScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<QueryDocumentSnapshot> _feed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _firebaseService.getFriendsOotdFeed();
      if (mounted) {
        setState(() {
          _feed = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    if (_feed.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFeed,
        color: Colors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('아직 친구들의 OOTD가 없습니다.', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: Colors.black,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: _feed.length,
        itemBuilder: (context, index) {
          final doc = _feed[index];
          final data = doc.data() as Map<String, dynamic>;
          return OotdPostWidget(
            ootdId: doc.id,
            data: data,
            firebaseService: _firebaseService,
          );
        },
      ),
    );
  }
}
