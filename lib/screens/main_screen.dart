import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'upload_screen.dart';
import 'profile_screen.dart';
import 'ootd_screen.dart';
import 'upload_ootd_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const OotdScreen(),
    const SizedBox.shrink(), // Index 2 is for Upload (+)
    const ProfileScreen(),
  ];

  void _showUploadBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '무엇을 추가할까요?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Icon(Icons.checkroom, color: Colors.white),
                  ),
                  title: const Text('옷장에 새 아이템 추가', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Icon(Icons.camera_alt_outlined, color: Colors.white),
                  ),
                  title: const Text('오늘의 OOTD 기록하기', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadOotdScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            _showUploadBottomSheet(context);
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.grid_view_rounded,
              color: _currentIndex == 0 ? Colors.black : Colors.grey[400],
              size: 28,
            ),
            label: '옷장',
          ),
          BottomNavigationBarItem(
            icon: Container(
              width: 26,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _currentIndex == 1 ? Colors.black : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person,
                color: _currentIndex == 1 ? Colors.black : Colors.grey[400],
                size: 18,
              ),
            ),
            label: 'OOTD',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.black,
              size: 30,
            ),
            label: '추가',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline,
              color: _currentIndex == 3 ? Colors.black : Colors.grey[400],
              size: 30,
            ),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}
