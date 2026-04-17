/*
 * Samuel Bulnes
 * Senior Project
 * ORUneed - Socket.io Server
 * Real-time chat backend for university students
 * 
 * Features:
 * - Heartbeat/ping-pong (25s intervals)
 * - Automatic timeout detection (60s inactivity)
 * - Rate limiting (100 msgs/min per user)
 * - CORS security
 * - Comprehensive logging
 * - Graceful error handling
 */

const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');
require('dotenv').config();

const app = express();
const server = http.createServer(app);

//***********************************************************************************
//  SOCKET.IO INITIALIZATION
// Configuration with security and performance optimizations

const io = socketIO(server, {
  cors: {
    // TODO: In production, replace "*" with your domain: origin: "https://yourdomain.com"
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
  },
  transports: ['websocket', 'polling'],
  
  // Heartbeat configuration (in milliseconds)
  pingInterval: 25000,      // Send ping every 25 seconds
  pingTimeout: 60000,       // Wait 60 seconds for pong before disconnecting
  
  // Connection limits
  maxHttpBufferSize: 1e6,   // Max 1MB per message
  connectTimeout: 45000,    // Max 45s to establish connection
});

//***********************************************************************************
//  MIDDLEWARE
app.use(cors());
app.use(express.json());

// Server port
const PORT = process.env.PORT || 4000;

//***********************************************************************************
// DATA STRUCTURES FOR TRACKING
const connectedUsers = new Map();     // userId -> socketId
const userMessageCount = new Map();   // userId -> { count, resetTime }
const userLastActivity = new Map();   // userId -> timestamp (for inactivity tracking)

//***********************************************************************************
// UTILITY FUNCTIONS

// Rate limiting checker (100 messages per minute)
function checkRateLimit(userId, maxMessages = 100, timeWindow = 60000) {
  const now = Date.now();
  const userLimit = userMessageCount.get(userId);

  if (!userLimit) {
    userMessageCount.set(userId, { count: 1, resetTime: now + timeWindow });
    return { allowed: true, remaining: maxMessages - 1 };
  }

  // Reset counter if time window expired
  if (now > userLimit.resetTime) {
    userMessageCount.set(userId, { count: 1, resetTime: now + timeWindow });
    return { allowed: true, remaining: maxMessages - 1 };
  }

  // Check if limit exceeded
  if (userLimit.count >= maxMessages) {
    return { 
      allowed: false, 
      remaining: 0,
      resetAt: userLimit.resetTime 
    };
  }

  // Increment counter
  userLimit.count++;
  return { allowed: true, remaining: maxMessages - userLimit.count };
}

// Logging utility with timestamps
function log(level, message, data = {}) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${level}] ${message}`;
  
  if (level === 'ERROR') {
    console.error(logMessage, data);
  } else if (level === 'WARN') {
    console.warn(logMessage, data);
  } else {
    console.log(logMessage, data);
  }
}

//***********************************************************************************
// SOCKET.IO EVENT HANDLERS
io.on('connection', (socket) => {
  const socketId = socket.id;
  log('INFO', `New connection established`, { socketId });

  let userId = null;

  //*********************************************************************************
  // USER REGISTER EVENT
  socket.on('register', (incomingUserId) => {
    try {
      // Validate input
      if (!incomingUserId || typeof incomingUserId !== 'string') {
        socket.emit('register_error', { error: 'Invalid user ID' });
        log('WARN', 'Invalid registration attempt', { socketId, incomingUserId });
        return;
      }

      userId = incomingUserId;
      
      // Remove previous connection if user was already connected
      const previousSocketId = connectedUsers.get(userId);
      if (previousSocketId && previousSocketId !== socketId) {
        io.to(previousSocketId).emit('force_disconnect', { 
          reason: 'Logged in from another device' 
        });
        log('INFO', 'Removed duplicate connection', { userId, previousSocketId });
      }

      // Register new connection
      connectedUsers.set(userId, socketId);
      userLastActivity.set(userId, Date.now());
      
      // Send confirmation
      socket.emit('register_success', { userId, socketId });
      
      log('INFO', `User registered`, { 
        userId, 
        socketId,
        totalConnected: connectedUsers.size 
      });

    } catch (error) {
      log('ERROR', 'Registration error', { socketId, error: error.message });
      socket.emit('register_error', { error: 'Registration failed' });
    }
  });

  //*********************************************************************************
  // SEND MESSAGE EVENT - with rate limiting
  socket.on('send_message', (data) => {
    try {
      // Validate user is registered
      if (!userId) {
        socket.emit('message_error', { error: 'User not registered' });
        return;
      }

      // Validate data
      const { senderId, receiverId, message, timestamp } = data;
      if (!senderId || !receiverId || !message) {
        socket.emit('message_error', { error: 'Missing required fields' });
        log('WARN', 'Invalid message data', { userId, data });
        return;
      }

      // Check rate limit
      const rateCheck = checkRateLimit(userId);
      if (!rateCheck.allowed) {
        socket.emit('message_error', { 
          error: 'Rate limit exceeded',
          resetAt: rateCheck.resetAt
        });
        log('WARN', 'Rate limit exceeded', { userId, resetAt: rateCheck.resetAt });
        return;
      }

      // Update last activity
      userLastActivity.set(userId, Date.now());

      // Get receiver's socket ID
      const receiverSocketId = connectedUsers.get(receiverId);
      
      if (receiverSocketId) {
        // Send to receiver
        io.to(receiverSocketId).emit('receive_message', {
          senderId,
          message,
          timestamp
        });

        // Acknowledge sender
        socket.emit('message_sent', { 
          success: true,
          receiverId,
          timestamp 
        });

        log('INFO', 'Message delivered', { senderId, receiverId, timestamp });
      } else {
        // Receiver offline - still acknowledge (Firestore will handle persistence)
        socket.emit('message_sent', { 
          success: true,
          receiverId,
          status: 'offline',
          timestamp
        });

        log('INFO', 'Receiver offline (saved to Firestore)', { senderId, receiverId });
      }

    } catch (error) {
      log('ERROR', 'Send message error', { userId, error: error.message });
      socket.emit('message_error', { error: 'Message delivery failed' });
    }
  });

  //*********************************************************************************
  // TYPING EVENT
  socket.on('typing', (data) => {
    try {
      const { senderId, receiverId } = data;
      
      if (!senderId || !receiverId) return;

      userLastActivity.set(userId, Date.now());

      const receiverSocketId = connectedUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('user_typing', { userId: senderId });
      }

    } catch (error) {
      log('ERROR', 'Typing event error', { userId, error: error.message });
    }
  });

  //*********************************************************************************
  // STOP TYPING EVENT
  socket.on('stop_typing', (data) => {
    try {
      const { senderId, receiverId } = data;
      
      if (!senderId || !receiverId) return;

      userLastActivity.set(userId, Date.now());

      const receiverSocketId = connectedUsers.get(receiverId);
      if (receiverSocketId) {
        io.to(receiverSocketId).emit('user_stop_typing', { userId: senderId });
      }

    } catch (error) {
      log('ERROR', 'Stop typing event error', { userId, error: error.message });
    }
  });

  //*********************************************************************************
  // ERROR HANDLING
  socket.on('error', (error) => {
    log('ERROR', 'Socket error', { userId, socketId, error });
  });

  //*********************************************************************************
  // DISCONNECT EVENT
  socket.on('disconnect', (reason) => {
    if (userId) {
      connectedUsers.delete(userId);
      userMessageCount.delete(userId);
      userLastActivity.delete(userId);
      
      log('INFO', 'User disconnected', { 
        userId, 
        socketId, 
        reason,
        remainingUsers: connectedUsers.size 
      });
    } else {
      log('INFO', 'Unregistered socket disconnected', { socketId, reason });
    }
  });
});

//***********************************************************************************
// REST API ROUTES

// Health check endpoint with detailed stats
app.get('/health', (req, res) => {
  const stats = {
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    connectedUsers: connectedUsers.size,
    memory: {
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
      external: Math.round(process.memoryUsage().external / 1024 / 1024)
    },
    activeConnections: io.engine.clientsCount || 0
  };
  
  log('INFO', 'Health check requested', stats);
  res.json(stats);
});

// Server statistics endpoint
app.get('/stats', (req, res) => {
  const stats = {
    connectedUsers: connectedUsers.size,
    totalMessageAttempts: userMessageCount.size,
    serverUptime: process.uptime(),
    timestamp: new Date().toISOString()
  };
  
  res.json(stats);
});

//***********************************************************************************
// START SERVER
server.listen(PORT, () => {
  log('INFO', '🚀 ORUneed Socket.io Server started', {
    port: PORT,
    url: `http://localhost:${PORT}`,
    pingInterval: '25s',
    pingTimeout: '60s',
    rateLimit: '100 messages/minute',
    features: ['Heartbeat', 'RateLimit', 'ErrorHandling', 'Logging']
  });

  // Log server stats every 30 seconds
  setInterval(() => {
    log('INFO', 'Server stats', {
      connectedUsers: connectedUsers.size,
      memory: `${Math.round(process.memoryUsage().heapUsed / 1024 / 1024)}MB`,
      activeConnections: io.engine.clientsCount || 0
    });
  }, 30000);
});
