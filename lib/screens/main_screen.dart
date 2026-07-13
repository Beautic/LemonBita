import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'upload_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import '../theme/app_theme.dart';
import 'ootd_screen.dart';
import 'upload_ootd_screen.dart';
import 'coordination_canvas_screen.dart';
import 'item_screen.dart';
import 'upload_item_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime? _lastPressedAt;

  final List<Widget> _pages = [
    const HomeScreen(),
    const OotdScreen(),
    const SizedBox.shrink(), // Index 2 is for Upload (+)
    const ItemScreen(),
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
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '무엇을 추가할까요?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Icon(Icons.checkroom, color: Colors.white),
                  ),
                  title: const Text('새 의류 등록하기', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('상의, 하의, 아우터, 신발 등 의류 아이템', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                    child: Icon(Icons.inventory_2_outlined, color: Colors.white),
                  ),
                  title: const Text('새 일반 아이템 등록하기', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('보드게임, 피규어, 향수, LP 등 일반 소장품', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadItemScreen(),
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
                    Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadOotdScreen(),
                        fullscreenDialog: true,
                      ),
                    ).then((uploaded) {
                      if (uploaded == true && mounted) {
                        setState(() {
                          _currentIndex = 1; // OOTD 탭으로 전환
                        });
                      }
                    });
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Icon(Icons.dashboard_customize_outlined, color: Colors.white),
                  ),
                  title: const Text('가상 코디 캔버스 (코디하기)', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CoordinationCanvasScreen(),
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // 1. 현재 탭이 첫 번째 탭(옷장, index=0)이 아닌 경우, 첫 번째 탭으로 이동시킵니다.
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        // 2. 이미 첫 번째 탭일 경우, 연속 두 번 누르면 종료되도록 제어합니다.
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('뒤로가기를 한 번 더 누르면 종료됩니다.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // 3. 2초 내에 두 번 누른 경우, 실제 앱을 종료 처리합니다.
        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      },
      child: Scaffold(
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
                color: _currentIndex == 0 ? AppColors.ink : AppColors.muted.withOpacity(0.5),
                size: 28,
              ),
              label: '옷장',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.collections_bookmark_outlined,
                color: _currentIndex == 1 ? AppColors.ink : AppColors.muted.withOpacity(0.5),
                size: 26,
              ),
              label: 'OOTD',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: const Center(
                  child: Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink, height: 1.1)),
                ),
              ),
              label: '추가',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.inventory_2_outlined,
                color: _currentIndex == 3 ? AppColors.ink : AppColors.muted.withOpacity(0.5),
                size: 26,
              ),
              label: '아이템',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.person_outline,
                color: _currentIndex == 4 ? AppColors.ink : AppColors.muted.withOpacity(0.5),
                size: 30,
              ),
              label: '프로필',
            ),
          ],
        ),
      ),
    );
  }
}
