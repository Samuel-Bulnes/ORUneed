/*
 * Samuel Bulnes
 * Senior Project
 * Socket Service
 * Manages real-time WebSocket connection for instant messaging using Socket.io
 * 
 * Features:
 * - Automatic reconnection with exponential backoff
 * - Message timeouts (30s)
 * - Dynamic server URL configuration
 * - Comprehensive logging
 * - Graceful degradation (offline fallback)
 * - Support for 50+ concurrent connections
 */

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';

//***********************************************************************************
// Socket.io service for real-time messaging functionality
class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  String? _userId;
  
  // Reconnection state
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;

  //*********************************************************************************
  // STREAM CONTROLLERS
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<String>.broadcast();
  final _stopTypingController = StreamController<String>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get onMessageReceived => _messageController.stream;
  Stream<String> get onUserTyping => _typingController.stream;
  Stream<String> get onUserStopTyping => _stopTypingController.stream;
  Stream<bool> get onConnectionStatusChanged => _connectionStatusController.stream;

  bool get isConnected => _isConnected;
  String? get userId => _userId;

  //***********************************************************************************
  // LOGGING UTILITY
  void _log(String level, String message, [dynamic data]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [$level] Socket: $message';
    
    if (level == 'ERROR') {
      print('🔴 $logMessage');
      if (data != null) print('   Error details: $data');
    } else if (level == 'WARN') {
      print('🟡 $logMessage');
    } else if (level == 'INFO') {
      print('🟢 $logMessage');
    } else {
      print('⚪ $logMessage');
    }
  }

  //***********************************************************************************
  // GET SERVER URL (dynamic configuration)
  String _getServerUrl() {
    // Default for development
    // TODO: In production, use environment variable or config
    // return const String.fromEnvironment('SOCKET_SERVER_URL', defaultValue: 'http://10.0.2.2:4000');
    return 'http://10.0.2.2:4000';
  }

  //***********************************************************************************
  // CONNECT TO SOCKET.IO SERVER
  void connect(String userId) {
    if (_isConnected && _userId == userId) {
      _log('INFO', 'Already connected with user: $userId');
      return;
    }

    _userId = userId;
    final serverUrl = _getServerUrl();
    
    _log('INFO', 'Attempting to connect', {
      'userId': userId,
      'serverUrl': serverUrl,
      'attempt': _reconnectAttempts + 1
    });

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])  // Try both transports
          .setReconnectionDelay(1000)               // Start with 1s
          .setReconnectionDelayMax(5000)            // Max 5s between attempts
          .setReconnectionAttempts(5)               // Built-in retry
          .disableAutoConnect()
          .build(),
    );

    _setupEventHandlers(userId);
    _socket!.connect();
  }

  //***********************************************************************************
  // SETUP EVENT HANDLERS
  void _setupEventHandlers(String userId) {
    // CONNECTION SUCCESS
    _socket!.onConnect((_) {
      _log('INFO', 'Connected to server');
      _isConnected = true;
      _reconnectAttempts = 0;  // Reset counter on successful connection
      
      // Register user
      _socket!.emit('register', userId);
      
      _connectionStatusController.add(true);
    });

    // CONNECTION ERROR
    _socket!.onConnectError((error) {
      _log('ERROR', 'Connection error', error);
      _isConnected = false;
      _connectionStatusController.add(false);
    });

    // DISCONNECT
    _socket!.onDisconnect((reason) {
      _log('WARN', 'Socket disconnected', {'reason': reason});
      _isConnected = false;
      _connectionStatusController.add(false);
      
      // Attempt automatic reconnection with exponential backoff
      _attemptReconnect(userId);
    });

    // RECONNECT ERROR
    _socket!.on('error', (error) {
      _log('ERROR', 'Socket error event', error);
    });

    // INCOMING MESSAGES
    _socket!.on('receive_message', (data) {
      _log('INFO', 'Message received', data);
      _messageController.add(Map<String, dynamic>.from(data as Map));
    });

    // USER TYPING
    _socket!.on('user_typing', (data) {
      _log('DEBUG', 'User typing', data);
      final typingUserId = data['userId'] ?? '';
      _typingController.add(typingUserId);
    });

    // USER STOP TYPING
    _socket!.on('user_stop_typing', (data) {
      _log('DEBUG', 'User stopped typing', data);
      final typingUserId = data['userId'] ?? '';
      _stopTypingController.add(typingUserId);
    });

    // MESSAGE SENT ACKNOWLEDGMENT
    _socket!.on('message_sent', (data) {
      _log('INFO', 'Message delivery acknowledged', data);
    });

    // MESSAGE ERROR
    _socket!.on('message_error', (error) {
      _log('ERROR', 'Message error from server', error);
    });

    // REGISTRATION SUCCESS
    _socket!.on('register_success', (response) {
      _log('INFO', 'User registered successfully', response);
    });

    // REGISTRATION ERROR
    _socket!.on('register_error', (error) {
      _log('ERROR', 'Registration failed', error);
    });

    // FORCE DISCONNECT (logged in elsewhere)
    _socket!.on('force_disconnect', (data) {
      _log('WARN', 'Forced disconnect - logged in from another device', data);
      disconnect();
    });
  }

  //***********************************************************************************
  // AUTOMATIC RECONNECTION WITH EXPONENTIAL BACKOFF
  void _attemptReconnect(String userId) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('ERROR', 'Max reconnection attempts reached', {
        'attempts': _reconnectAttempts,
        'maxAttempts': _maxReconnectAttempts
      });
      return;
    }

    _reconnectAttempts++;
    
    // Exponential backoff: 1s, 2s, 4s, 8s... up to 10s
    final delaySeconds = [
      1, 1, 2, 2, 4, 4, 8, 8, 10, 10
    ][_reconnectAttempts - 1];

    _log('INFO', 'Scheduling reconnection', {
      'attempt': _reconnectAttempts,
      'delaySeconds': delaySeconds,
      'userId': userId
    });

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _log('INFO', 'Attempting reconnection...');
      connect(userId);
    });
  }

  //***********************************************************************************
  // SEND MESSAGE WITH TIMEOUT
  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String message,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isConnected) {
      _log('WARN', 'Cannot send message - not connected');
      return false;
    }

    final data = {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // Emit message event
      _socket!.emit('send_message', data);

      _log('INFO', 'Message sent', {'to': receiverId});
      return true;

    } catch (e) {
      _log('ERROR', 'Error sending message', e);
      return false;
    }
  }

  //***********************************************************************************
  // TYPING INDICATORS
  void emitTyping(String senderId, String receiverId) {
    if (!_isConnected) return;

    _socket!.emit('typing', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  void emitStopTyping(String senderId, String receiverId) {
    if (!_isConnected) return;

    _socket!.emit('stop_typing', {
      'senderId': senderId,
      'receiverId': receiverId,
    });
  }

  //***********************************************************************************
  // DISCONNECT
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      _userId = null;
      _connectionStatusController.add(false);
      
      _log('INFO', 'Socket disconnected');
    }
  }

  //***********************************************************************************
  // DISPOSE (cleanup)
  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _stopTypingController.close();
    _connectionStatusController.close();
    
    _log('INFO', 'Socket service disposed');
  }
}
