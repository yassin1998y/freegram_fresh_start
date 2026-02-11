const io = require('socket.io-client');

// Configuration
const SERVER_URL = 'http://localhost:8080'; // Adjust as needed
const BOT_COUNT = 50;
const TEST_DURATION_MS = 15000; // 15 seconds

const bots = [];
const matches = [];

console.log(`🚀 Starting Stress Test with ${BOT_COUNT} bots...`);

function createBot(id) {
    const socket = io(SERVER_URL, {
        transports: ['websocket'],
        forceNew: true,
        reconnection: false,
    });

    const bot = { id, socket, role: null, roomId: null, matched: false };

    socket.on('connect', () => {
        // console.log(`[Bot ${id}] Connected`);
        socket.emit('find_random_match');
    });

    socket.on('match_found', (data) => {
        // console.log(`[Bot ${id}] Match found:`, data);
        if (bot.matched) {
            console.error(`[Bot ${id}] ❌ Double match detected!`);
        }
        bot.matched = true;
        bot.roomId = data.roomId;
        bot.role = data.role;
        matches.push({ botId: id, ...data });
    });

    socket.on('disconnect', () => {
        // console.log(`[Bot ${id}] Disconnected`);
    });

    return bot;
}

// Launch Bots
for (let i = 0; i < BOT_COUNT; i++) {
    bots.push(createBot(i + 1));
}

// Verification after delay
setTimeout(() => {
    console.log(`\n🛑 Test Completed. Analyzing results...`);

    // 1. Verify deterministic roles and no self-matching
    const rooms = {};
    let selfMatchCount = 0;

    matches.forEach(m => {
        if (!rooms[m.roomId]) {
            rooms[m.roomId] = { offer: [], answer: [] };
        }
        rooms[m.roomId][m.role].push(m.botId);
    });

    let validRooms = 0;
    let invalidRooms = 0;

    Object.keys(rooms).forEach(roomId => {
        const room = rooms[roomId];
        const offers = room.offer.length;
        const answers = room.answer.length;

        if (offers === 1 && answers === 1) {
            validRooms++;
            // Check self match (impossible if logic is correct, but let's check IDs if we had them)
            if (room.offer[0] === room.answer[0]) {
                console.error(`❌ Self match in room ${roomId} (Bot ${room.offer[0]})`);
                selfMatchCount++;
            }
        } else {
            console.error(`❌ Invalid Room ${roomId}: Offers=${offers}, Answers=${answers}`);
            invalidRooms++;
        }
    });

    // 2. Queue Duplicate Check (Indirect)
    // If waitingQueue had duplicates, we might see same socket matched multiple times?
    // We check if any bot received multiple 'match_found' events.
    // The client logic above checks `if (bot.matched) error`.

    // 3. Match Rate
    const totalMatches = matches.length;
    const expectedMatches = Math.floor(BOT_COUNT / 2) * 2; // Pairs

    console.log(`\n--- Report ---`);
    console.log(`Total Bots: ${BOT_COUNT}`);
    console.log(`Total Matches Events: ${totalMatches}`);
    console.log(`Valid Rooms (Pairs): ${validRooms}`);
    console.log(`Invalid Rooms: ${invalidRooms}`);
    console.log(`Self Matches: ${selfMatchCount}`);

    if (totalMatches >= expectedMatches && invalidRooms === 0 && selfMatchCount === 0) {
        console.log(`\n✅ SIGNALLING STRESS TEST PASSED`);
    } else {
        console.log(`\n❌ SIGNALLING STRESS TEST FAILED`);
    }

    // Cleanup
    bots.forEach(b => b.socket.disconnect());
    process.exit(0);

}, TEST_DURATION_MS);
