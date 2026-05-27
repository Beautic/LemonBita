import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'coordination_canvas_screen.dart';

class FriendClosetScreen extends StatelessWidget {
  final Map<String, dynamic> friendData;
  const FriendClosetScreen({super.key, required this.friendData});

  @override
  Widget build(BuildContext context) {
    final String friendUid = friendData['uid'];
    final String friendNickname = friendData['nickname'] ?? '친구';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('$friendNickname님의 옷장', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CoordinationCanvasScreen(
                      friendUid: friendUid,
                      friendNickname: friendNickname,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.style),
              label: Text('$friendNickname님 코디 도와주기', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clothes')
                  .where('userId', isEqualTo: friendUid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('등록된 옷이 없습니다.', style: TextStyle(color: Colors.grey)));
                }

                final clothes = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: clothes.length,
                  itemBuilder: (context, index) {
                    final data = clothes[index].data() as Map<String, dynamic>;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: Colors.grey[200],
                        child: Image.network(
                          data['imageUrl'] ?? '',
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                          errorBuilder: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
