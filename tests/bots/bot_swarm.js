const puppeteer = require('puppeteer');
const path = require('path');

// CLI Arguments: node bot_swarm.js [count]
const args = process.argv.slice(2);
const BOT_COUNT = parseInt(args[0]) || 5;

const BOT_CLIENT_PATH = `file://${path.join(__dirname, 'bot_client.html')}`;

const PERSONAS = [
    'SPAMMER',    // High freq
    'MALICIOUS',  // SQLi/XSS
    'FRAGMENTED', // Long strings
    'MEDIA',      // Fake file uploads
    'GHOST'       // Idle
];

async function launchBot(id) {
    // Round-robin assignment
    const persona = PERSONAS[(id - 1) % PERSONAS.length];
    console.log(`[Launcher] Launching Bot ${id} as ${persona}...`);

    // Launch Browser
    const browser = await puppeteer.launch({
        headless: "new", // Headless but with fake media
        args: [
            '--use-fake-ui-for-media-stream',
            '--use-fake-device-for-media-stream',
            '--allow-file-access-from-files', // For local HTML
            '--no-sandbox',
            '--disable-setuid-sandbox'
        ]
    });

    const page = await browser.newPage();

    // Capture Console Logs
    page.on('console', msg => {
        // Filter for important logs or print all with prefix
        const text = msg.text();
        if (text.includes('[Bot]')) {
            console.log(`[Bot ${id}-${persona}] ${text}`); // If we prefixed in client
        }
    });

    // Pass persona in URL
    await page.goto(`${BOT_CLIENT_PATH}?persona=${persona}&id=${id}`);

    // Keep alive?
    // We intentionally don't close browser.
    return browser;
}

async function startSwarm() {
    console.log(`🚀 Starting Swarm with ${BOT_COUNT} bots...`);

    const bots = [];
    for (let i = 0; i < BOT_COUNT; i++) {
        bots.push(await launchBot(i + 1));
        // Stagger launches slightly to prevent server spike
        await new Promise(r => setTimeout(r, 500));
    }

    console.log(`✅ All ${BOT_COUNT} bots launched! Press Ctrl+C to stop.`);
}

startSwarm().catch(err => console.error(err));
