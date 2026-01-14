import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/message.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- User Operations ---

  /// Checks if a username is globally unique
  Future<bool> isUsernameAvailable(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  /// Creates or updates the user's profile in Firestore
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    required String username,
    String? profilePhotoUrl,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);

    // Check if username is taken first (double check)
    if (!(await isUsernameAvailable(username))) {
      // If updating existing user, check if it's their own username
      final doc = await userRef.get();
      if (doc.exists && doc.data()?['username'] == username) {
        // Same user keeping username, allowed
      } else {
        throw Exception('Bu kullanıcı adı alınmış.');
      }
    }

    await userRef.set({
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'profilePhotoUrl': profilePhotoUrl ?? 'assets/Beta2.png', // Default
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  // --- Group Operations ---

  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required String creatorUsername,
  }) async {
    final groupRef = _firestore.collection('groups').doc();

    await groupRef.set({
      'groupId': groupRef.id,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': creatorUid,
      'creatorUsername': creatorUsername,
      'admins': [creatorUid],
      'members': [creatorUid],
      'isPublic': true, // Default public via link
      'inviteLink': 'foresee://group/${groupRef.id}',
      'memberDetails': {
        creatorUid: {
          'username': creatorUsername,
          'role': 'admin',
          'joinedAt': DateTime.now().toIso8601String(),
        },
      },
    });

    return groupRef.id;
  }

  Future<void> joinGroup(String groupId, String uid, String username) async {
    final groupRef = _firestore.collection('groups').doc(groupId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(groupRef);
      if (!snapshot.exists) {
        throw Exception('Grup bulunamadı.');
      }

      final members = List<String>.from(snapshot.data()?['members'] ?? []);
      if (members.length >= 8) {
        // Max 8 rule
        throw Exception('Grup dolu (Max 8 kişi).');
      }

      if (members.contains(uid)) return; // Already joined

      transaction.update(groupRef, {
        'members': FieldValue.arrayUnion([uid]),
        'memberDetails.$uid': {
          'username': username,
          'role': 'member',
          'joinedAt': DateTime.now().toIso8601String(),
        },
      });
    });
  }

  Future<void> leaveGroup(String groupId, String uid) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    await groupRef.update({
      'members': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
      'memberDetails.$uid': FieldValue.delete(),
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    // Delete all messages subcollection first (optional but cleaner)
    final messages = await groupRef.collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
    await groupRef.delete();
  }

  Future<void> kickMember(String groupId, String uid) async {
    await leaveGroup(groupId, uid); // Same logic
  }

  Future<void> updateMemberRole(String groupId, String uid, String role) async {
    final groupRef = _firestore.collection('groups').doc(groupId);
    await groupRef.update({
      if (role == 'admin')
        'admins': FieldValue.arrayUnion([uid])
      else
        'admins': FieldValue.arrayRemove([uid]),
      'memberDetails.$uid.role': role,
    });
  }

  // --- Messaging ---

  Stream<QuerySnapshot> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String senderUid,
    required String senderUsername,
    required String senderPhoto,
    required String content,
    List<String>? mentionedUids,
    String? replyToId,
    String? imageUrl,
  }) async {
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .add({
          'senderId': senderUid,
          'senderUsername': senderUsername,
          'senderPhoto': senderPhoto,
          'content': content,
          'timestamp': FieldValue.serverTimestamp(),
          'type': imageUrl != null ? 'image' : 'text',
          'mentions': mentionedUids ?? [],
          'replyTo': replyToId,
          'imageUrl': imageUrl,
        });
  }

  Future<void> migrateMessagesToGroup(
    String groupId,
    List<Message> messages,
  ) async {
    if (messages.isEmpty) return;

    final batch = _firestore.batch();
    final collectionRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages');

    for (var msg in messages) {
      // Use existing ID if possible, or new one
      // If we use existing ID, we ensure idempotency
      final docRef = collectionRef.doc(msg.id.isNotEmpty ? msg.id : null);

      batch.set(docRef, {
        'senderId': msg.isUser
            ? (msg.metadata?['senderId'] ?? _auth.currentUser?.uid)
            : 'ai_foresee',
        'senderUsername':
            msg.senderUsername ??
            (msg.isUser
                ? (_auth.currentUser?.displayName ?? 'Kullanıcı')
                : 'ForeSee'),
        'senderPhoto':
            msg.senderPhotoUrl ??
            (msg.isUser ? null : 'logo3.png'), // Use logo3 for AI
        'content': msg.content,
        'timestamp': msg.timestamp,
        'type': 'text', // Default to text
        'imageUrl': msg.imageUrl,
        // Add other fields if necessary
      });
    }

    await batch.commit();
  }
}
