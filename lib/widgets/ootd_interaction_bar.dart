import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'ootd_post_widget.dart';

class OotdInteractionBar extends StatefulWidget {
  final String ootdId;
  final String ownerId;
  final List<dynamic> likedBy;
  final int commentCount;
  final FirebaseService firebaseService;
  final Function(List<dynamic>) onLikeToggled;

  const OotdInteractionBar({
    super.key,
    required this.ootdId,
    required this.ownerId,
    required this.likedBy,
    required this.commentCount,
    required this.firebaseService,
    required this.onLikeToggled,
  });

  @override
  State<OotdInteractionBar> createState() => _OotdInteractionBarState();
}

class _OotdInteractionBarState extends State<OotdInteractionBar> {
  bool _isLiking = false;

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    final myUid = widget.firebaseService.currentUserId;
    if (myUid == null) return;

    final isLiked = widget.likedBy.contains(myUid);
    final newLikedBy = List.from(widget.likedBy);

    if (isLiked) {
      newLikedBy.remove(myUid);
    } else {
      newLikedBy.add(myUid);
    }

    widget.onLikeToggled(newLikedBy);
    setState(() => _isLiking = true);

    try {
      await widget.firebaseService.toggleOotdLike(widget.ootdId, widget.ownerId, isLiked);
    } catch (e) {
      // Revert on error
      final revertedLikedBy = List.from(newLikedBy);
      if (isLiked) {
        revertedLikedBy.add(myUid);
      } else {
        revertedLikedBy.remove(myUid);
      }
      widget.onLikeToggled(revertedLikedBy);
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _showCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CommentsSheet(
          ootdId: widget.ootdId,
          ownerId: widget.ownerId,
          firebaseService: widget.firebaseService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.firebaseService.currentUserId;
    final isLiked = myUid != null && widget.likedBy.contains(myUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.black),
                onPressed: _toggleLike,
              ),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined, color: Colors.black),
                onPressed: _showCommentsSheet,
              ),
              const Spacer(),
            ],
          ),
        ),
        if (widget.likedBy.isNotEmpty || widget.commentCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              '좋아요 ${widget.likedBy.length}개 · 댓글 ${widget.commentCount}개',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
