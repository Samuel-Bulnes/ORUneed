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
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
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
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a chat from a job post',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // User avatar with first letter of name
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1E1B4B),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
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
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: Colors.grey[600],
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
                        style: TextStyle(
                          color: Colors.grey[600],
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
                            color: Colors.grey,
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            chat.lastMessage,
                            style: TextStyle(
                              color: Colors.grey[700],
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

              //************************************************************************
              // Chevron icon to indicate navigation
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
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