/*
 * Samuel Bulnes
 * Senior Project
 * ORUneed - Socket.io Server
 * Real-time chat backend for university students
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
// Enables WebSocket communication with CORS enabled

const io = socketIO(server, {
  cors: {
    origin: "*", // TODO: In production, restrict this to your domain
    methods: ["GET", "POST"]
  }
});

//***********************************************************************************
//  MIDDLEWARE
app.use(cors());          // Allow cross-origin requests
app.use(express.json());  // Parse JSON request bodies

// Server port (runs on 4000 by default)
const PORT = process.env.PORT || 4000;

//***********************************************************************************
// CONNECTED USERS MAP
// Temporary in-memory storage for connected users:
//   Key   -> Firebase userId
//   Value -> Socket.io connection ID
// Later you can store this with Redis for scalability.
const connectedUsers = new Map();

//***********************************************************************************
// SOCKET.IO EVENT HANDLERS
io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);

  //*********************************************************************************
  // USER REGISTER EVENT
  // Called when Flutter sends the user's Firebase UID.
  // This links the user to their socket connection.
  socket.on('register', (userId) => {
    connectedUsers.set(userId, socket.id);
    console.log(`User registered: ${userId}`);
  });

  //***********************************************************************************
  // SEND MESSAGE EVENT
  // Flutter emits: { senderId, receiverId, message, timestamp }
  // The server forwards the message to the receiver if online.
  socket.on('send_message', (data) => {
    const { senderId, receiverId, message, timestamp } = data;
    
    console.log(`Message from ${senderId} to ${receiverId}: ${message}`);
    
    // Get receiver's socket ID
    const receiverSocketId = connectedUsers.get(receiverId);
    
    if (receiverSocketId) {
      // Emit message to receiver
      io.to(receiverSocketId).emit('receive_message', {
        senderId,
        message,
        timestamp
      });

      // Acknowledge sender
      socket.emit('message_sent', { success: true });

    } else {
      // User is offline → notify sender
      socket.emit('message_sent', { 
        success: false, 
        error: 'User offline' 
      });
    }
  });

  //***********************************************************************************
  // TYPING EVENT
  // Notifies receiver that sender is typing.
  socket.on('typing', (data) => {
    const { senderId, receiverId } = data;
    const receiverSocketId = connectedUsers.get(receiverId);
    
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('user_typing', { userId: senderId });
    }
  });

  //***********************************************************************************
  // STOP TYPING EVENT
  // Notifies receiver that sender stopped typing.
  socket.on('stop_typing', (data) => {
    const { senderId, receiverId } = data;
    const receiverSocketId = connectedUsers.get(receiverId);
    
    if (receiverSocketId) {
      io.to(receiverSocketId).emit('user_stop_typing', { userId: senderId });
    }
  });

  //***********************************************************************************
  // DISCONNECT EVENT
  // Removes user from the connectedUsers list when they leave.
  socket.on('disconnect', () => {
    for (let [userId, socketId] of connectedUsers.entries()) {
      if (socketId === socket.id) {
        connectedUsers.delete(userId);
        console.log(`User disconnected: ${userId}`);
        break;
      }
    }
  });
});

//***********************************************************************************
// HEALTH CHECK ROUTE
// Allows client or monitoring services to confirm server status.
// Example: GET /health
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK',
    message: 'iNeed server running',
    connectedUsers: connectedUsers.size 
  });
});

//***********************************************************************************
// START SERVER
server.listen(PORT, () => {
  console.log(`
  🚀 iNeed Server started
  📡 Port: ${PORT}
  🌐 http://localhost:${PORT}
  👥 Connected users: 0
  `);
});
