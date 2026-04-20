/*
 * Samuel Bulnes
 * Senior Project
 * Chat List Screen
 * Displays all active conversations with message previews
 */

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import '../models/chat_model.dart';
import '../utils/constants.dart';
import 'chat_screen.dart';

//*************************************************************************************
// Screen that displays a list of all active chats for the current user
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  String? _currentUserId;
  final Set<String> _deletingChatIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Get the current user's ID from Firebase Auth
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    // Verify user is logged in
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ORUneed'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.neonBlue,
        centerTitle: true,
        elevation: 0,
      ),

      //***********************************************************************************
      // CHAT LIST
      // Displays real-time list of user's chats using Firestore stream
      body: StreamBuilder<List<Chat>>(
        // Listen to real-time updates of user's chats
        stream: _chatService.getUserChats(_currentUserId!),
        builder: (context, snapshot) {
          // Show loading indicator while waiting for data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Handle errors
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final chats = snapshot.data ?? [];

          //****************************************************************************
          // Show empty state if no chats exist
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 100,
                    color: const Color(0xFF666666),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Start a chat from a job post',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            );
          }

          //******************************************************************************
          // Build list of chat cards
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              // Get the name of the other participant in the chat
              final otherUserName = chat.getOtherUserName(_currentUserId!);
              // Check if current user sent the last message
              final isLastMessageMine = chat.lastSenderId == _currentUserId;

              return _buildChatCard(
                context: context,
                chat: chat,
                userName: otherUserName,
                isLastMessageMine: isLastMessageMine,
              );
            },
          );
        },
      ),
    );
  }

  //***********************************************************************************
  // Builds a single chat card widget
  Widget _buildChatCard({
    required BuildContext context,
    required Chat chat,
    required String userName,
    required bool isLastMessageMine,
  }) {
    // Format the timestamp for display
    final timeStr = _formatTime(chat.updatedAt);
    final isDeleting = _deletingChatIds.contains(chat.id);

    return Dismissible(
      key: ValueKey(chat.id),
      direction: isDeleting ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteChat(chatId: chat.id, userName: userName),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: InkWell(
          onTap: isDeleting
              ? null
              : () {
                  // Navigate to the chat conversation screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: chat.id,
                        otherUserId: chat.getOtherUserId(_currentUserId!),
                        otherUserName: userName,
                        jobId: chat.jobId,
                        jobTitle: chat.jobTitle,
                      ),
                    ),
                  );
                },
          onLongPress: isDeleting
              ? null
              : () => _showChatActions(chatId: chat.id, userName: userName),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User avatar with first letter of name
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.neonBlue,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

              //************************************************************************
              // Chat content (name, job title, last message)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row with user name and timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Job title (if exists)
                      if (chat.jobTitle != null) ...[
                        Text(
                          chat.jobTitle!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Last message preview
                      Row(
                        children: [
                          // Show check icon if current user sent the last message
                          if (isLastMessageMine)
                            const Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              chat.lastMessage,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                if (isDeleting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: 'Chat actions',
                    onSelected: (value) {
                      if (value == 'open') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chat.id,
                              otherUserId: chat.getOtherUserId(_currentUserId!),
                              otherUserName: userName,
                              jobId: chat.jobId,
                              jobTitle: chat.jobTitle,
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        _showChatActions(chatId: chat.id, userName: userName);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'open',
                        child: Text('Open chat'),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Delete chat'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //***********************************************************************************
  // Shows the available chat actions in a cross-device friendly bottom sheet.
  Future<void> _showChatActions({
    required String chatId,
    required String userName,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Remove chat with $userName'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmDeleteChat(chatId: chatId, userName: userName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  //***********************************************************************************
  // Confirms and deletes a chat, keeping feedback clear for the user.
  Future<bool> _confirmDeleteChat({
    required String chatId,
    required String userName,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Remove chat', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove your conversation with $userName from your chat list?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.neonBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return false;
    }

    setState(() => _deletingChatIds.add(chatId));

    try {
      final deletedForEveryone =
          await _chatService.deleteChat(chatId, _currentUserId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletedForEveryone
                  ? 'Chat with $userName deleted for both users.'
                  : 'Chat with $userName removed from your list.',
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to delete chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _deletingChatIds.remove(chatId));
      }
    }
  }

  //***********************************************************************************
  // Formats a DateTime to a user-friendly relative time string
  // - Today: shows time ("3:45 PM")
  // - Yesterday: shows "Yesterday"
  // - This week: shows day name ("Monday")
  // - Older: shows date ("Jan 15")
  
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today: show time
      return DateFormat('h:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week: show day name
      return DateFormat('EEEE').format(dateTime);
    } else {
      // Older: show date
      return DateFormat('MMM d').format(dateTime);
    }
  }
}