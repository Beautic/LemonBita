import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'friend_closet_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final friends = await _firebaseService.getFriends();
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingFriends = false);
      }
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _firebaseService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _sendRequest(String uid) async {
    try {
      await _firebaseService.sendFriendRequest(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('친구 요청을 보냈습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('요청 실패: $e')));
      }
    }
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('검색 결과', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final user = _searchResults[index];
            final bool isAlreadyFriend = _friends.any((f) => f['uid'] == user['uid']);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                backgroundImage: user['profileImageUrl']?.isNotEmpty == true
                    ? NetworkImage(user['profileImageUrl'])
                    : null,
                child: user['profileImageUrl']?.isEmpty == true ? const Icon(Icons.person, color: Colors.grey) : null,
              ),
              title: Text(user['nickname'] ?? '이름 없음'),
              subtitle: Text(user['email'] ?? ''),
              trailing: isAlreadyFriend
                  ? const Text('친구', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                  : OutlinedButton(
                      onPressed: () => _sendRequest(user['uid']),
                      child: const Text('요청', style: TextStyle(color: Colors.black)),
                    ),
            );
          },
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildFriendRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebaseService.getFriendRequestsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        
        final requests = snapshot.data!.docs;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('받은 친구 요청', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index].data() as Map<String, dynamic>;
                final fromUid = req['uid'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: req['profileImageUrl']?.isNotEmpty == true
                        ? NetworkImage(req['profileImageUrl'])
                        : null,
                    child: req['profileImageUrl']?.isEmpty == true ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  title: Text(req['nickname'] ?? '이름 없음'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => _firebaseService.rejectFriendRequest(fromUid),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          if (_friends.length >= 10) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('친구는 최대 10명까지만 가능합니다.')));
                            return;
                          }
                          await _firebaseService.acceptFriendRequest(fromUid);
                          _loadFriends(); // 새로고침
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('내 친구 목록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_friends.length}/10 명', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (_friends.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('등록된 친구가 없습니다. 위에서 친구를 검색해보세요!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              final friend = _friends[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: friend['profileImageUrl']?.isNotEmpty == true
                      ? NetworkImage(friend['profileImageUrl'])
                      : null,
                  child: friend['profileImageUrl']?.isEmpty == true ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                title: Text(friend['nickname'] ?? '이름 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FriendClosetScreen(friendData: friend),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('친구 관리', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '이메일, 휴대폰 번호, 닉네임 검색',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSearching ? null : _performSearch,
                    style: FilledButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('검색'),
                  ),
                ],
              ),
            ),
            _buildSearchResults(),
            _buildFriendRequests(),
            _buildFriendsList(),
          ],
        ),
      ),
    );
  }
}
