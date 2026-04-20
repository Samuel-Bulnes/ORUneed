/*
 * Samuel Bulnes
 * Senior Project
 * Chat Screen
 * Real-time one-on-one messaging interface with typing indicators
 */

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/firestore_service.dart';
import '../models/message_model.dart';
import '../utils/constants.dart';

//*************************************************************************************
// Screen that displays a one-on-one chat conversation
// Supports real-time messaging via Socket.io and persistent storage via Firestore
class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? jobId;
  final String? jobTitle;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.jobId,
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
  final FirestoreService _firestoreService = FirestoreService();

  // Controllers for input and scrolling
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Current user information from Firebase Auth
  String? _currentUserId;
  String? _currentUserName;

  // Typing indicator state
  bool _isTyping = false;
  Timer? _typingTimer;

  // Temporary completion survey state
  int _selectedSurveyRating = 5;
  bool _isSubmittingCompletion = false;
  
  // Stream subscriptions for real-time updates
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  //**********************************************************************************
  // Initialize current user information
  void _initializeUser() async {
    // Get current user information from Firebase Auth
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown';

    // Fetch user name from Firestore for accuracy
    if (_currentUserId != null) {
      final user = await _firestoreService.getUser(_currentUserId!);
      if (user != null) {
        _currentUserName = user.name;
      }
    }

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
      // Don't scroll automatically - let StreamBuilder handle it
    });

    // Listen for typing indicator from other user
    _typingSubscription = _socketService.onUserTyping.listen((userId) {
      if (userId == widget.otherUserId) {
        setState(() => _isTyping = true);
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatService.getChatStream(widget.chatId),
      builder: (context, chatSnapshot) {
        final chatData = chatSnapshot.data?.data() ?? {};
        final participantIds = List<String>.from(
          chatData['participantIds'] ?? [_currentUserId!, widget.otherUserId],
        );
        final confirmations =
            Map<String, dynamic>.from(chatData['completionConfirmations'] ?? {});
        final completionRequested = chatData['completionRequested'] == true;
        final requestedById = chatData['completionRequestedBy'] as String?;
        final currentConfirmed = confirmations[_currentUserId!] == true;
        final bothConfirmed = participantIds.isNotEmpty &&
            participantIds.every((id) => confirmations[id] == true);

        final effectiveJobId = (chatData['jobId'] as String?) ?? widget.jobId;
        final hasJobContext =
            effectiveJobId != null && effectiveJobId.trim().isNotEmpty;

        // workerId is null for legacy chats → fall back to allowing both (old behaviour)
        final workerIdInChat = chatData['workerId'] as String?;
        final isWorker =
            workerIdInChat == null || _currentUserId == workerIdInChat;

        final requestedByName = requestedById == _currentUserId
            ? 'You'
            : widget.otherUserName;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.neonBlue),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display other user's name
                Text(
                  widget.otherUserName,
                  style: TextStyle(
                    color: AppColors.neonBlue,
                    fontSize: 18,
                  ),
                ),
                // Display job title if this chat is related to a job
                if (widget.jobTitle != null)
                  Text(
                    widget.jobTitle!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            actions: [
              // Only the worker can initiate completion; poster sees 'Completed' once done
              if (hasJobContext && (isWorker || bothConfirmed))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: (bothConfirmed ||
                            currentConfirmed ||
                            _isSubmittingCompletion ||
                            !isWorker)
                        ? null
                        : () => _showCompletionDialog(
                              completionRequested: completionRequested,
                              isWorker: isWorker,
                            ),
                    child: Text(
                      bothConfirmed
                          ? 'Completed'
                          : (currentConfirmed ? 'Confirmed' : 'Complete'),
                      style: TextStyle(
                        color: bothConfirmed ? Colors.greenAccent : AppColors.neonBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          //**********************************************************************************
          body: Column(
            children: [
              if (hasJobContext && (completionRequested || bothConfirmed))
                _buildCompletionStatus(
                  completionRequested: completionRequested,
                  bothConfirmed: bothConfirmed,
                  currentConfirmed: currentConfirmed,
                  requestedByName: requestedByName,
                ),

              // Messages list area
              Expanded(
                child: StreamBuilder<List<Message>>(
                  // Listen to real-time message updates from Firestore
                  stream: _chatService.getMessages(widget.chatId),
                  builder: (context, snapshot) {
                    // Show loading indicator while fetching messages
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
                    }

                    // Handle errors
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: AppColors.textPrimary)));
                    }

                    final messages = snapshot.data ?? [];

                    // Show empty state if no messages
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Start the conversation!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      // Add extra item for typing indicator if active
                      itemCount: messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show typing indicator at the beginning (since list is reversed)
                        if (index == 0 && _isTyping) {
                          return _buildTypingIndicator();
                        }

                        // Adjust index for typing indicator offset
                        final messageIndex = _isTyping ? index - 1 : index;
                        
                        // For reversed list, we need to reverse the message order
                        final actualIndex = messages.length - 1 - messageIndex;
                        if (actualIndex < 0 || actualIndex >= messages.length) return SizedBox.shrink();
                        
                        final message = messages[actualIndex];
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
      },
    );
  }

  //**********************************************************************************
  // Completion status card shown at top of chat when confirmation flow is active
  Widget _buildCompletionStatus({
    required bool completionRequested,
    required bool bothConfirmed,
    required bool currentConfirmed,
    required String requestedByName,
  }) {
    if (bothConfirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: AppColors.cardBackground,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Job completed by both parties.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (completionRequested && !currentConfirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: Colors.orange, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work completion reported by $requestedByName.',
              style: TextStyle(
                color: AppColors.neonBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rate the work to confirm:',
              style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Rating:', style: TextStyle(color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _selectedSurveyRating,
                  items: [1, 2, 3, 4, 5]
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value/5'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedSurveyRating = value);
                  },
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmittingCompletion
                      ? null
                      : () => _submitCompletion(
                            rating: _selectedSurveyRating,
                            completionRequested: true,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1B4B),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.neonBlue, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: AppColors.neonBlue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You already confirmed. Waiting for the other person to confirm.',
              style: TextStyle(
                color: AppColors.neonBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  //**********************************************************************************
  // Completion confirmation dialog — workers just confirm, only the poster rates
  Future<void> _showCompletionDialog({
    required bool completionRequested,
    required bool isWorker,
  }) async {
    int tempRating = _selectedSurveyRating;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              title: Text('Confirm completed work', style: TextStyle(color: AppColors.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isWorker
                        ? 'The payer will be notified to confirm and rate the work.'
                        : 'Your confirmation will finalize the job.',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  // Rating picker only shown to the poster (payer)
                  if (!isWorker) ...[
                    const SizedBox(height: 12),
                    Text('Rate the work:', style: TextStyle(color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: tempRating,
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value/5'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => tempRating = value);
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppColors.neonBlue)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _submitCompletion(
                      rating: isWorker ? 0 : tempRating,
                      completionRequested: completionRequested,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonBlue,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //**********************************************************************************
  // Submits completion confirmation and only completes job when both sides confirm
  Future<void> _submitCompletion({
    required int rating,
    required bool completionRequested,
  }) async {
    if (_currentUserId == null) return;

    setState(() => _isSubmittingCompletion = true);

    try {
      if (!completionRequested) {
        await _chatService.requestJobCompletion(
          chatId: widget.chatId,
          userId: _currentUserId!,
        );
      }

      await _chatService.confirmJobCompletion(
        chatId: widget.chatId,
        userId: _currentUserId!,
        rating: rating,
      );


    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error while confirming: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCompletion = false);
      }
    }
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
          // Neon blue for current user, darker for other user
          color: isMe ? AppColors.neonBlue : AppColors.cardBackground,
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
                color: isMe ? Colors.black : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            // Timestamp
            Text(
              DateFormat('h:mm a').format(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.black54 : AppColors.textSecondary,
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
          color: AppColors.cardBackground,
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
      color: AppColors.cardBackground,
      child: Row(
        children: [
          // Text input field
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Write a message...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF444444)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF444444)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.neonBlue, width: 2),
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
              decoration: BoxDecoration(
                color: AppColors.neonBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}