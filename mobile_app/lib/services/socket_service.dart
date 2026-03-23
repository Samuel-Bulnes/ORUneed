/*
 * Samuel Bulnes
 * Senior Project
 * Socket Service
 * Manages real-time WebSocket connection for instant messaging using Socket.io
 */

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

//***********************************************************************************
// Socket.io service for real-time messaging functionality
class SocketService {
  // Singleton pattern: a single instance of SocketService throughout the app
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket; // Socket.io connection instance
  bool _isConnected = false;

  //*********************************************************************************
  // STREAM CONTROLLERS
  // Used to broadcast events to multiple UI listeners (Message, Typing, Stop-Typing)

  // Broadcasts incoming messages to all listeners
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  // Broadcasts when other user starts typing
  final _typingController = StreamController<String>.broadcast();

  // Broadcasts when other user stops typing
  final _stopTypingController = StreamController<String>.broadcast();

  // Public streams to listen from the UI
  Stream<Map<String, dynamic>> get onMessageReceived => _messageController.stream;
  Stream<String> get onUserTyping => _typingController.stream;
  Stream<String> get onUserStopTyping => _stopTypingController.stream;

  // Getter to check connection status from outside
  bool get isConnected => _isConnected;

  //***********************************************************************************
  // CONNECT TO SOCKET.IO SERVER
  // Handles connection, reconnection, event listeners, and registering a user
  void connect(String userId) {
    // Prevent multiple connections
    if (_isConnected) {
      print('Socket already connected');
      return;
    }

    /// Server URL configuration
    // Note: 10.0.2.2 is the special IP address for Android emulator to access localhost
    // For iOS simulator, use 'localhost' or '127.0.0.1'
    // For physical devices, use your computer's local IP (e.g., '192.168.1.100')
    const serverUrl = 'http://10.0.2.2:4000';

    // Initialize socket with configuration
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket']) // Force websocket usage
          .disableAutoConnect()         // Do not auto-connect; call connect() manually
          .build(),
    );

    //***********************************************************************************
    //  Connection event handlers

    _socket!.onConnect((_) {
      print('Socket connected');
      _isConnected = true;

      // Register this user with the Socket.io server
      _socket!.emit('register', userId);
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      print('Socket connection error: $error');
      _isConnected = false;
    });

    //***********************************************************************************
    //  Incoming events from server

    // MESSAGE RECEIVED
    _socket!.on('receive_message', (data) {
      print('Message received: $data');
      _messageController.add(data);
    });

    // USER IS TYPING
    _socket!.on('user_typing', (data) {
      print('User typing: ${data['userId']}');
      _typingController.add(data['userId']);
    });

    // USER STOPPED TYPING
    _socket!.on('user_stop_typing', (data) {
      print('User stopped typing: ${data['userId']}');
      _stopTypingController.add(data['userId']);
    });

    // Establish the connection
    _socket!.connect();
  }

  //***********************************************************************************
  //  SEND MESSAGE TO SERVER
  // Emits 'send_message' event with payload containing message details

  void sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) {
    // Check if connected before attempting to send
    if (!_isConnected) {
      print('Attempted to send message while disconnected');
      return;
    }

    // Prepare message data payload
    final data = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('Sending message: $data');

    // Emit the message event to server
    _socket!.emit('send_message', data);
  }

  //***********************************************************************************
  // EMIT TYPING EVENTS
  // Notifies server the user is typing or stopped typing

  void emitTyping(String senderId, String receiverId) {
    if (!_isConnected) return;

    _socket!.emit('typing', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }


  //***********************************************************************************
  // EMIT TYPING INDICATOR
  // Notifies server that current user is typing
  void emitStopTyping(String senderId, String receiverId) {
    if (!_isConnected) return;

    _socket!.emit('stop_typing', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  //***********************************************************************************
  // DISCONNECT SOCKET
  // Clean shutdown of socket connection (used on logout or app exit)

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();  // Close connection
      _socket!.dispose();     // Clean up resources
      _socket = null;
      _isConnected = false;
      print('Socket manually disconnected');
    }
  }

  //***********************************************************************************
  // DISPOSE RESOURCES
  // Closes controllers to prevent memory leaks
  // Should be called typically on app termination

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _stopTypingController.close();
  }
}
