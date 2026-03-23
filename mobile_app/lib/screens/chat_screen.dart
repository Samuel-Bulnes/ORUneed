/*
 * Samuel Bulnes
 * Senior Project
 * Chat Screen
 * Real-time one-on-one messaging interface with typing indicators
 */

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../models/message_model.dart';

//*************************************************************************************
// Screen that displays a one-on-one chat conversation
// Supports real-time messaging via Socket.io and persistent storage via Firestore
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? jobTitle;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.jobTitle,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

//*************************************************************************************
class _ChatScreenState extends State<ChatScreen> {
  // Services for chat and real-time messaging
  final ChatService _chatService = ChatService();
  final SocketService _socketService = SocketService();

  // Controllers for input and scrolling
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Current user information from Firebase Auth
  String? _currentUserId;
  String? _currentUserName;

  // Typing indicator state
  bool _isTyping = false;
  Timer? _typingTimer;
  
  // Stream subscriptions for real-time updates
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    // Get current user information from Firebase Auth
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown';
    _initializeChat();
  }

  //**********************************************************************************
  // Initializes the chat by connecting to Socket.io and setting up listeners
  void _initializeChat() {
    if (_currentUserId == null) return;

    // Connect to Socket.io if not already connected
    if (!_socketService.isConnected) {
      _socketService.connect(_currentUserId!);
    }

    // Listen for incoming messages in real-time
    _messageSubscription = _socketService.onMessageReceived.listen((data) {
      print('📩 Message received in UI: $data');
      _scrollToBottom();
    });

    // Listen for typing indicator from other user
    _typingSubscription = _socketService.onUserTyping.listen((userId) {
      if (userId == widget.otherUserId) {
        setState(() => _isTyping = true);
        _scrollToBottom();
      }
    });

    // Listen for stop typing indicator
    _socketService.onUserStopTyping.listen((userId) {
      if (userId == widget.otherUserId) {
        setState(() => _isTyping = false);
      }
    });

    // Mark all messages in this chat as read
    _chatService.markMessagesAsRead(widget.chatId, _currentUserId!);
  }

  //**********************************************************************************
  // Smoothly scrolls to the bottom of the message list
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  //**********************************************************************************
  // Sends a message via Socket.io (real-time) and Firestore (persistence)
  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    // Clear the input field immediately for better UX
    _messageController.clear();

    // Send via Socket.io for instant delivery
    _socketService.sendMessage(
      senderId: _currentUserId!,
      receiverId: widget.otherUserId,
      message: text,
    );

    // Save to Firestore for persistence
    await _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: _currentUserId!,
      senderName: _currentUserName ?? 'Unknown',
      text: text,
    );

    // Stop typing indicator
    _socketService.emitStopTyping(_currentUserId!, widget.otherUserId);

    _scrollToBottom();
  }

  //**********************************************************************************
  // Handles text input changes and emits typing indicator
  void _onTextChanged(String text) {
    if (text.isNotEmpty && _currentUserId != null) {
      // Emit typing indicator to other user
      _socketService.emitTyping(_currentUserId!, widget.otherUserId);

      // Cancel previous timer and start new one
      // Stops typing indicator after 2 seconds of inactivity
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _socketService.emitStopTyping(_currentUserId!, widget.otherUserId);
      });
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Verify user is logged in
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in')),
      );
    }

    //**********************************************************************************
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B4B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display other user's name
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            // Display job title if this chat is related to a job
            if (widget.jobTitle != null)
              Text(
                widget.jobTitle!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),

      //**********************************************************************************
      body: Column(
        children: [
          // Messages list area
          Expanded(
            child: StreamBuilder<List<Message>>(
              // Listen to real-time message updates from Firestore
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                // Show loading indicator while fetching messages
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Handle errors
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                // Show empty state if no messages
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Start the conversation!',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  // Add extra item for typing indicator if active
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show typing indicator at the end if other user is typing
                    if (index == messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }

                    final message = messages[index];
                    // Check if message is from current user
                    final isMe = message.senderId == _currentUserId;

                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          // Message input area
          _buildMessageInput(),
        ],
      ),
    );
  }

  //**********************************************************************************
  // Builds a message bubble widget
  // Aligns to right for current user's messages, left for other user's messages
  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          // Dark color for current user, white for other user
          color: isMe ? const Color(0xFF1E1B4B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          // Limit bubble width to 70% of screen width
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message text
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            // Timestamp
            Text(
              DateFormat('h:mm a').format(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //**********************************************************************************
  // Builds the "typing..." indicator with animated dots
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Three animated dots with staggered delays
            _buildDot(),
            const SizedBox(width: 4),
            _buildDot(delay: 200),
            const SizedBox(width: 4),
            _buildDot(delay: 400),
          ],
        ),
      ),
    );
  }

  //**********************************************************************************
  // Builds a single animated dot for the typing indicator
  Widget _buildDot({int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  //**********************************************************************************
  // Builds the message input field with send button
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          // Text input field
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: 'Write a message...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFFE5E5E5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1B4B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}