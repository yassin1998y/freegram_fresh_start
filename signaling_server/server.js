const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*", // Allow all origins for production flexibility
        methods: ["GET", "POST"]
    }
});

const PORT = process.env.PORT || 8080;

// Queue for random matching (Array of sockets)
let waitingQueue = [];

// --- Heartbeat & Cleanup ---
// Run every 2000ms to clean up disconnected sockets from the queue
setInterval(() => {
    const initialLength = waitingQueue.length;
    waitingQueue = waitingQueue.filter(socket => {
        // Keep only connected sockets
        return socket.connected === true;
    });

    if (waitingQueue.length < initialLength) {
        console.log(`[${new Date().toISOString()}] [QUEUE_CLEANUP] Removed ${initialLength - waitingQueue.length} disconnected sockets from queue.`);
    }
}, 2000);

io.on('connection', (socket) => {
    console.log(`[${new Date().toISOString()}] User connected: ${socket.id}`);

    // --- Random Matching ---
    socket.on('find_random_match', () => {
        // Atomic FIFO Matching
        if (waitingQueue.length === 0) {
            // Queue is empty, push current socket
            waitingQueue.push(socket);
            socket.emit('waiting_for_match');
            console.log(`[${new Date().toISOString()}] [QUEUE_JOIN] User ${socket.id} joined waiting queue.`);
        } else {
            // Queue has users, match with the first one (FIFO)

            // Pop the first user
            const partnerSocket = waitingQueue.shift();

            // Sanity check: Ensure we don't match with ourselves (if user spammed button)
            if (partnerSocket.id === socket.id) {
                waitingQueue.push(socket);
                socket.emit('waiting_for_match');
                return;
            }

            // Assign role BEFORE joining to prevent race conditions in client logic if needed,
            // but primarily we need to JOIN first.
            const roomId = `match_${partnerSocket.id}_${socket.id}_${Date.now()}`;

            // JOIN FIRST
            socket.join(roomId);
            partnerSocket.join(roomId);

            // Use io.to(roomId) to ensure we are emitting to the room we just joined?
            // Actually, we need to send specific roles to specific sockets.
            // But we must ensure the 'join' async operation (if any) completes. 
            // In Socket.io v4, join is synchronous.

            // Send match_found to each individually to assign roles
            partnerSocket.emit('match_found', { roomId, role: 'answer', partnerId: socket.id });
            socket.emit('match_found', { roomId, role: 'offer', partnerId: partnerSocket.id });


            console.log(`[${new Date().toISOString()}] [MATCH_CREATED] Room: ${roomId} between ${socket.id} (offer) and ${partnerSocket.id} (answer)`);
        }
    });

    // --- WebRTC Signaling ---
    // Strict forwarding to the specific roomId
    socket.on('offer', (payload) => {
        const { roomId, offer } = payload;
        if (roomId && offer) {
            // FIXED: Added roomId back into the emitted payload
            socket.to(roomId).emit('offer', { offer, roomId, senderId: socket.id });
        }
    });

    socket.on('answer', (payload) => {
        const { roomId, answer } = payload;
        if (roomId && answer) {
            // FIXED: Added roomId back into the emitted payload
            socket.to(roomId).emit('answer', { answer, roomId, senderId: socket.id });
        }
    });

    socket.on('candidate', (payload) => {
        const { roomId, candidate } = payload;
        if (roomId && candidate) {
            // FIXED: Added roomId back into the emitted payload. This is critical for ICE negotiation.
            socket.to(roomId).emit('candidate', { candidate, roomId, senderId: socket.id });
        }
    });

    // --- Robust Disconnect Logic ---
    socket.on('disconnecting', () => {
        // Iterate through socket's active rooms and emit peer_disconnected
        // socket.rooms is a Set containing socket.id and rooms provided by join
        for (const room of socket.rooms) {
            if (room !== socket.id) {
                socket.to(room).emit('peer_disconnected', { userId: socket.id });
                console.log(`[${new Date().toISOString()}] [PEER_DISCONNECT] User ${socket.id} disconnected from room ${room}`);
            }
        }
    });

    socket.on('disconnect', () => {
        // Immediately remove from waitingQueue
        const index = waitingQueue.findIndex(s => s.id === socket.id);
        if (index !== -1) {
            waitingQueue.splice(index, 1);
            console.log(`[${new Date().toISOString()}] [QUEUE_CLEANUP] User ${socket.id} removed from queue on disconnect.`);
        }

        console.log(`[${new Date().toISOString()}] User disconnected: ${socket.id}`);
    });
});

server.listen(PORT, () => {
    console.log(`Signaling Server running on port ${PORT}`);
});
