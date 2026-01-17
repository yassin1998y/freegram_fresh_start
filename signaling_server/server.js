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

// Queue for random matching
let waitingUser = null;

io.on('connection', (socket) => {
    console.log(`[${new Date().toISOString()}] User connected: ${socket.id}`);

    // --- Private 1-on-1 Calls ---
    socket.on('join_private_call', ({ roomId }) => {
        socket.join(roomId);
        console.log(`[${new Date().toISOString()}] User ${socket.id} joined room ${roomId}`);
        // Notify others in the room
        socket.to(roomId).emit('user_joined', { userId: socket.id });
    });

    // --- Random Matching ---
    socket.on('find_random_match', () => {
        console.log(`[${new Date().toISOString()}] User ${socket.id} looking for random match`);

        if (waitingUser) {
            // Match found!
            const partnerSocket = waitingUser;

            // Check if the waiting user is effectively the same socket (edge case) or disconnected
            if (partnerSocket.id === socket.id) {
                return;
            }

            const roomId = `match_${partnerSocket.id}_${socket.id}`;

            // Join both to the new room
            socket.join(roomId);
            partnerSocket.join(roomId);

            // Notify both users
            io.to(roomId).emit('match_found', { roomId, partnerId: partnerSocket.id === socket.id ? '?' : 'peer' }); // Simple notification
            // Actually, better to send specific per-user match info if needed, but for now robust simple emit:
            // We will emit 'match_found' with the roomId. The client can then initiate the offer.
            // To be purely symmetric, we can pick one as initiator.
            // Let's stick to the prompt: generate roomId, emit match_found to both.

            socket.emit('match_found', { roomId, role: 'offer' });
            partnerSocket.emit('match_found', { roomId, role: 'answer' });

            console.log(`[${new Date().toISOString()}] Match created: ${roomId} between ${socket.id} and ${partnerSocket.id}`);

            waitingUser = null;
        } else {
            // No one waiting, add to queue
            waitingUser = socket;
            socket.emit('waiting_for_match');
            console.log(`[${new Date().toISOString()}] User ${socket.id} added to waiting queue`);
        }
    });

    // --- WebRTC Signaling ---
    socket.on('offer', (payload) => {
        // payload should contain { roomId, offer }
        const { roomId, offer } = payload;
        console.log(`[${new Date().toISOString()}] Offer from ${socket.id} to room ${roomId}`);
        socket.to(roomId).emit('offer', { offer, senderId: socket.id });
    });

    socket.on('answer', (payload) => {
        const { roomId, answer } = payload;
        console.log(`[${new Date().toISOString()}] Answer from ${socket.id} to room ${roomId}`);
        socket.to(roomId).emit('answer', { answer, senderId: socket.id });
    });

    socket.on('candidate', (payload) => {
        const { roomId, candidate } = payload;
        console.log(`[${new Date().toISOString()}] Candidate from ${socket.id} to room ${roomId}`);
        socket.to(roomId).emit('candidate', { candidate, senderId: socket.id });
    });

    // --- Disconnect ---
    socket.on('disconnect', () => {
        console.log(`[${new Date().toISOString()}] User disconnected: ${socket.id}`);

        // Remove from random match queue if there
        if (waitingUser && waitingUser.id === socket.id) {
            waitingUser = null;
            console.log(`[${new Date().toISOString()}] Removed ${socket.id} from waiting queue`);
        }

        // Notify rooms provided they are in any (Socket.IO auto leaves, but we might want to notify peers)
        // socket.rooms is empty on disconnect event usually, so we rely on client side or tracking if needed.
        // However, for a simple signaling server, we can't easily iterate all rooms efficiently on disconnect without tracking.
        // BUT the prompt asks: "If user was in a call, emit peer_disconnected to the room."
        // socket.io rooms are automatically left upon disconnection. 
        // We can't know which room they were in unless we track it or if the 'disconnecting' event provides it.
    });

    // Use 'disconnecting' to capture rooms before leaving
    socket.on('disconnecting', () => {
        const rooms = socket.rooms;
        for (const room of rooms) {
            if (room !== socket.id) {
                socket.to(room).emit('peer_disconnected', { userId: socket.id });
                console.log(`[${new Date().toISOString()}] Emitted peer_disconnected to room ${room}`);
            }
        }
    });
});

server.listen(PORT, () => {
    console.log(`Signaling Server running on port ${PORT}`);
});
