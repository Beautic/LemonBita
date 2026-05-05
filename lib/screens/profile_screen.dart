import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'ootd_screen.dart';
import 'collections_tab.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    final userName = user?.email?.split('@').first ?? '사용자';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black),
              onPressed: () {
                // TODO: 설정 화면 열기
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.black),
              onPressed: () async {
                await firebaseService.logout();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 프로필 헤더
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200]),
                    child: const Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn('게시물', '0'),
                        _buildStatColumn('팔로워', '0'),
                        _buildStatColumn('팔로잉', '0'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 탭바
            const TabBar(
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(icon: Icon(Icons.grid_on)),
                Tab(icon: Icon(Icons.bookmark_border)),
              ],
            ),
            
            // 탭바 뷰
            const Expanded(
              child: TabBarView(
                children: [
                  OotdScreen(isProfileTab: true),
                  CollectionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
