/*
 * Samuel Bulnes
 * Senior Project
 * Chat Service
 * Manages chat creation, messaging, and real-time message streaming with Firestore
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

//***********************************************************************************
// Chat service that handles all chat-related operations with Firestore
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //*********************************************************************************
  // CHAT DOCUMENT STREAM
  // Real-time listener for a single chat document (metadata and completion state)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getChatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  //*********************************************************************************
  // CREATE OR FETCH CHAT BETWEEN TWO USERS
  // Ensures only ONE chat exists per user pair (no duplicates)

  Future<String> getOrCreateChat({
    required String currentUserId,
    required String currentUserName,
    required String otherUserId,
    required String otherUserName,
    String? jobId,     // Optional: link chat to a specific job/request
    String? jobTitle,  // Optional: title of the job
    String? workerId,  // The user who does the job (acceptedById)
  }) async {
    try {
      // Look for existing chats where the current user is a participant
      final existingChat = await _firestore
          .collection('chats')
          .where('participantIds', arrayContains: currentUserId)
          .get();

      // Check if any of these chats include the other user as well
      for (var doc in existingChat.docs) {
        List<String> participants =
            List<String>.from(doc.data()['participantIds']);

        if (participants.contains(otherUserId)) {
          await doc.reference.update({
            'deletedBy': FieldValue.arrayRemove([currentUserId]),
            'hiddenFor': FieldValue.arrayRemove([currentUserId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('Existing chat found: ${doc.id}');
          return doc.id; // Return ID of existing chat
        }
      }

      // No existing chat -> Create a new chat document
      final chatData = {
        'participantIds': [currentUserId, otherUserId],
        'participantNames': {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        'jobId': jobId,
        'jobTitle': jobTitle,
        'workerId': workerId,
        'lastMessage': 'Chat started', // Initial system message
        'lastSenderId': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final newChat = await _firestore.collection('chats').add(chatData);

      print('New chat created: ${newChat.id}');
      return newChat.id;

    } catch (e) {
      print('Error creating/fetching chat: $e');
      rethrow;
    }
  }

  //*********************************************************************************
  // SEND MESSAGE
  // Creates new message document + updates chat with last message info
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      final messageData = {
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false, // All new messages start as unread
      };

      // Store new message in Firestore
      await _firestore.collection('messages').add(messageData);

      // Update "lastMessage" info inside the chat document
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': text,
        'lastSenderId': senderId,
        'deletedBy': FieldValue.delete(),
        'hiddenFor': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Message saved to Firestore');

    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  //*********************************************************************************
  // REQUEST JOB COMPLETION
  // First confirmation entry point: marks current user as confirmed and notifies the peer
  Future<void> requestJobCompletion({
    required String chatId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'completionRequested': true,
        'completionRequestedBy': userId,
        'completionRequestedAt': FieldValue.serverTimestamp(),
        'completionConfirmations.$userId': true,
        'deletedBy': FieldValue.delete(),
        'hiddenFor': FieldValue.delete(),
        'lastMessage': 'Work marked as completed',
        'lastSenderId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error requesting job completion: $e');
      rethrow;
    }
  }

  //*********************************************************************************
  // CONFIRM JOB COMPLETION WITH TEMP RATING
  // Marks a participant as confirmed and completes the job only when both users confirm
  Future<void> confirmJobCompletion({
    required String chatId,
    required String userId,
    required int rating,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    String? finalizedJobId;
    bool finalizedInChat = false;

    try {
      await _firestore.runTransaction((transaction) async {
        final chatSnap = await transaction.get(chatRef);
        if (!chatSnap.exists) {
          throw Exception('Chat not found');
        }

        final chatData = chatSnap.data() as Map<String, dynamic>;
        final participantIds =
            List<String>.from(chatData['participantIds'] ?? const []);
        final confirmations =
            Map<String, dynamic>.from(chatData['completionConfirmations'] ?? {});
        final workerIdInChat = chatData['workerId'] as String?;
        final isWorker = workerIdInChat != null && userId == workerIdInChat;

        confirmations[userId] = true;

        final updates = <String, dynamic>{
          'completionRequested': true,
          'completionConfirmations.$userId': true,
          'deletedBy': FieldValue.delete(),
          'hiddenFor': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Only save the rating when the poster (payer) confirms — that's the worker's rating
        if (!isWorker) {
          updates['workerRating'] = rating;
        }

        final allConfirmed = participantIds.isNotEmpty &&
            participantIds.every((id) => confirmations[id] == true);

        if (allConfirmed) {
          updates['completionFinalizedAt'] = FieldValue.serverTimestamp();
          updates['jobStatus'] = 'completed';
          updates['lastMessage'] = 'Job completed by both parties';
          updates['lastSenderId'] = userId;

          final jobId = chatData['jobId'] as String?;
          if (jobId != null && jobId.isNotEmpty) {
            finalizedJobId = jobId;
          }
          finalizedInChat = true;
        }

        transaction.update(chatRef, updates);
      });

      // Keep confirmation success even if the user cannot update /jobs directly.
      if (finalizedInChat && finalizedJobId != null) {
        try {
          await _firestore.collection('jobs').doc(finalizedJobId).update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') {
            rethrow;
          }
          print(
            'Job status update skipped due to permissions for user $userId on job $finalizedJobId',
          );
        }
      }
    } catch (e) {
      print('Error confirming job completion: $e');
      rethrow;
    }
  }

  //*********************************************************************************
  // REAL-TIME MESSAGE STREAM
  // Listens to messages for a specific chat using Firestore snapshots
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
  }

  //*********************************************************************************
  // REAL-TIME LIST OF CHATS FOR A USER
  // Returns user's chats sorted by activity (updatedAt DESC)
  Stream<List<Chat>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final hiddenFor = List<String>.from(data['hiddenFor'] ?? const []);
            final deletedBy = List<String>.from(data['deletedBy'] ?? const []);
            return !hiddenFor.contains(userId) && !deletedBy.contains(userId);
          })
          .map((doc) => Chat.fromFirestore(doc))
          .toList();
    });
  }

  //*********************************************************************************
  // MARK MESSAGES AS READ
  // Marks all messages in a chat NOT sent by current user as "read"

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Query all unread messages not sent by this user
      final unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      // Use batch update for efficiency
      final batch = _firestore.batch();

      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('Messages marked as read');

    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  //*********************************************************************************
  // GET UNREAD MESSAGE COUNT
  // Useful for badges, notifications, and unread indicators

  Future<int> getUnreadCount(String chatId, String userId) async {
    try {
      final unreadMessages = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadMessages.docs.length;

    } catch (e) {
      print('Error counting unread messages: $e');
      return 0;
    }
  }

  //*********************************************************************************
  // DELETE CHAT FOR CURRENT USER
  // First removal hides the chat for that user. When both users remove it, the
  // chat and its messages are permanently deleted.
  Future<bool> deleteChat(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    bool deletePermanently = false;

    try {
      await _firestore.runTransaction((transaction) async {
        final chatSnap = await transaction.get(chatRef);
        if (!chatSnap.exists) {
          throw Exception('Chat not found');
        }

        final chatData = chatSnap.data() as Map<String, dynamic>;
        final participantIds =
            List<String>.from(chatData['participantIds'] ?? const []);
        final deletedBy = {
          ...List<String>.from(chatData['deletedBy'] ?? const []),
          ...List<String>.from(chatData['hiddenFor'] ?? const []),
        };

        if (!participantIds.contains(userId)) {
          throw Exception('User is not part of this chat');
        }

        deletedBy.add(userId);
        deletePermanently =
            participantIds.isNotEmpty && participantIds.every(deletedBy.contains);

        if (deletePermanently) {
          transaction.update(chatRef, {
            'deletedBy': deletedBy.toList(),
            'updatedAt': FieldValue.serverTimestamp(),
            'pendingPermanentDelete': true,
          });
          return;
        }

        transaction.update(chatRef, {
          'deletedBy': deletedBy.toList(),
          'hiddenFor': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (deletePermanently) {
        final messages = await _firestore
            .collection('messages')
            .where('chatId', isEqualTo: chatId)
            .get();

        final batch = _firestore.batch();
        for (final doc in messages.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(chatRef);
        await batch.commit();
        print('Chat permanently deleted: $chatId');
        return true;
      }

      print('Chat removed for user: $userId');
      return false;

    } catch (e) {
      print('Error deleting chat: $e');
      rethrow;
    }
  }
}
