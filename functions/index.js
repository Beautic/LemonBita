const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// 1. 좋아요 카운트 자동화 및 푸시 알림
exports.onLikeCreated = functions.firestore
    .document('ootds/{ootdId}/likes/{userId}')
    .onCreate(async (snap, context) => {
        const { ootdId, userId } = context.params;

        // 1-1. 카운트 증가
        const ootdRef = db.collection('ootds').doc(ootdId);
        await ootdRef.update({
            likeCount: admin.firestore.FieldValue.increment(1)
        });

        // 1-2. 알림 전송 (FCM)
        // 작성자 정보 가져오기
        const ootdDoc = await ootdRef.get();
        if (!ootdDoc.exists) return null;
        
        const ootdData = ootdDoc.data();
        const targetUserId = ootdData.userId;

        // 자기 자신에게는 알림을 보내지 않음
        if (targetUserId === userId) return null;

        // 좋아요를 누른 유저 정보 가져오기
        const likerDoc = await db.collection('users').doc(userId).get();
        const likerName = likerDoc.exists ? likerDoc.data().displayName : '누군가';

        // 알림 데이터베이스 기록 (인앱 알림용)
        await db.collection('notifications').doc(targetUserId).collection('items').add({
            type: 'like',
            actorId: userId,
            actorName: likerName,
            targetType: 'ootd',
            targetId: ootdId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false
        });

        // FCM 토큰 가져오기 및 푸시 발송
        const targetUserDoc = await db.collection('users').doc(targetUserId).get();
        if (!targetUserDoc.exists) return null;
        
        const tokens = targetUserDoc.data().fcmTokens || [];
        if (tokens.length === 0) return null;

        const payload = {
            notification: {
                title: '새로운 좋아요❤️',
                body: `${likerName}님이 회원님의 OOTD를 좋아합니다.`,
            },
            data: {
                type: 'like',
                ootdId: ootdId
            }
        };

        await admin.messaging().sendToDevice(tokens, payload);
        return null;
    });

exports.onLikeDeleted = functions.firestore
    .document('ootds/{ootdId}/likes/{userId}')
    .onDelete(async (snap, context) => {
        const { ootdId } = context.params;
        const ootdRef = db.collection('ootds').doc(ootdId);
        await ootdRef.update({
            likeCount: admin.firestore.FieldValue.increment(-1)
        });
    });

// 2. 댓글 카운트 자동화
exports.onCommentCreated = functions.firestore
    .document('ootds/{ootdId}/comments/{commentId}')
    .onCreate(async (snap, context) => {
        const { ootdId } = context.params;
        const ootdRef = db.collection('ootds').doc(ootdId);
        await ootdRef.update({
            commentCount: admin.firestore.FieldValue.increment(1)
        });
    });

exports.onCommentDeleted = functions.firestore
    .document('ootds/{ootdId}/comments/{commentId}')
    .onDelete(async (snap, context) => {
        const { ootdId } = context.params;
        const ootdRef = db.collection('ootds').doc(ootdId);
        await ootdRef.update({
            commentCount: admin.firestore.FieldValue.increment(-1)
        });
    });
