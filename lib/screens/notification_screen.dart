import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'friends_screen.dart';
// 필요 시 ootd detail 화면 import 등 연동

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('새로운 알림이 없습니다.', style: TextStyle(color: Colors.grey)));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final data = notif.data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final type = data['type'];

              IconData iconData = Icons.notifications;
              Color iconColor = Colors.grey;
              if (type == 'friend_request') {
                iconData = Icons.person_add;
                iconColor = Colors.blue;
              } else if (type == 'friend_accept') {
                iconData = Icons.person;
                iconColor = Colors.green;
              } else if (type == 'ootd_like') {
                iconData = Icons.favorite;
                iconColor = Colors.red;
              } else if (type == 'ootd_comment') {
                iconData = Icons.comment;
                iconColor = Colors.orange;
              } else if (type == 'outfit_suggestion') {
                iconData = Icons.checkroom;
                iconColor = Colors.purple;
              }

              return Container(
                color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: data['senderProfileUrl']?.isNotEmpty == true
                        ? NetworkImage(data['senderProfileUrl'])
                        : null,
                    child: data['senderProfileUrl']?.isEmpty == true ? Icon(iconData, color: iconColor) : null,
                  ),
                  title: Text(data['message'] ?? ''),
                  subtitle: Text(_formatTimestamp(data['createdAt'])),
                  onTap: () {
                    if (!isRead) {
                      firebaseService.markNotificationAsRead(notif.id);
                    }
                    if (type == 'friend_request') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsScreen()));
                    }
                    // TODO: OOTD 상세페이지나 코디 추천 페이지로 이동
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.month}월 ${dt.day}일 ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
