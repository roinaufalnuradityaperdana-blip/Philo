import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import os from 'node:os';

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'suoro-smoke-'));
const receiverDir = path.join(tmpDir, 'receiver_downloads');
fs.mkdirSync(receiverDir, { recursive: true });

console.log(`[1] Setup receiver node at: ${receiverDir}`);

let sessionApproved = false;

// 1. Embedded HTTP Receiver
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'GET' && url.pathname === '/api/v1/info') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ id: 'win-node', name: 'Roi-Windows-PC', os: 'windows' }));
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/transfer/request') {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      const manifest = JSON.parse(body);
      console.log(`[Receiver] Permintaan masuk dari ${manifest.sender.name}: ${manifest.items.length} file (${manifest.totalSize} bytes)`);
      // Simulate prompt approval
      sessionApproved = true;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ sessionId: manifest.sessionId, status: 'accepted' }));
    });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/transfer/stream') {
    if (!sessionApproved) {
      res.writeHead(403);
      res.end('Unauthorized session');
      return;
    }
    const fileName = url.searchParams.get('fileName') || 'streamed.bin';
    const destPath = path.join(receiverDir, fileName);
    const writeStream = fs.createWriteStream(destPath);

    let received = 0;
    req.on('data', chunk => {
      received += chunk.length;
    });
    req.pipe(writeStream);

    writeStream.on('finish', () => {
      console.log(`[Receiver] Berhasil streaming ${received} bytes ke: ${destPath}`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'completed', bytes: received }));
    });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/transfer/text') {
    let body = '';
    req.on('data', chunk => (body += chunk));
    req.on('end', () => {
      const payload = JSON.parse(body);
      console.log(`[Receiver] Menerima clipboard teks: "${payload.text}"`);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'received' }));
    });
    return;
  }

  res.writeHead(404);
  res.end();
});

server.listen(0, '127.0.0.1', async () => {
  const port = server.address().port;
  console.log(`[2] Receiver listening on 127.0.0.1:${port}`);

  // Generate 5MB binary file on sender
  const senderFile = path.join(tmpDir, 'large_sample.dat');
  const buffer5MB = crypto.randomBytes(5 * 1024 * 1024);
  fs.writeFileSync(senderFile, buffer5MB);
  const originalHash = crypto.createHash('sha256').update(buffer5MB).digest('hex');
  console.log(`[Sender] File 5MB dibuat, SHA-256: ${originalHash}`);

  // Sender step 1: Request Transfer Handshake
  console.log('[Sender] Step 1: Mengirim transfer handshake request...');
  const reqPayload = JSON.stringify({
    sessionId: 'test-session-uuid-1234',
    sender: { name: 'Android-Pixel-Phone', os: 'android' },
    type: 'file',
    totalSize: buffer5MB.length,
    items: [{ id: 'item-0', name: 'large_sample.dat', size: buffer5MB.length, mime: 'application/octet-stream' }]
  });

  const handshakeRes = await fetch(`http://127.0.0.1:${port}/api/v1/transfer/request`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: reqPayload
  });
  const handshakeJson = await handshakeRes.json();
  console.log(`[Sender] Respon handshake: ${JSON.stringify(handshakeJson)}`);

  if (handshakeJson.status !== 'accepted') {
    throw new Error('Handshake rejected');
  }

  // Sender step 2: Stream chunked file binary
  console.log('[Sender] Step 2: Streaming 5MB binary data...');
  const streamRes = await fetch(`http://127.0.0.1:${port}/api/v1/transfer/stream?sessionId=test-session-uuid-1234&fileName=large_sample.dat`, {
    method: 'POST',
    duplex: 'half',
    body: fs.createReadStream(senderFile)
  });
  const streamJson = await streamRes.json();
  console.log(`[Sender] Respon stream: ${JSON.stringify(streamJson)}`);

  // Sender step 3: Send clipboard text
  console.log('[Sender] Step 3: Mengirim pesan teks...');
  const textRes = await fetch(`http://127.0.0.1:${port}/api/v1/transfer/text`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text: 'https://github.com/roi/suoro - tautan drop' })
  });
  console.log(`[Sender] Status teks: ${textRes.status}`);

  // Verification: Verify SHA-256 hash of received file
  const receivedFile = path.join(receiverDir, 'large_sample.dat');
  const receivedBuffer = fs.readFileSync(receivedFile);
  const receivedHash = crypto.createHash('sha256').update(receivedBuffer).digest('hex');
  console.log(`[Verification] Received SHA-256: ${receivedHash}`);

  if (receivedHash !== originalHash) {
    console.error('FATAL: SHA-256 mismatch!');
    process.exit(1);
  } else {
    console.log('SUCCESS: SHA-256 match 100%! P2P Streaming verified.');
  }

  // Cleanup
  server.close(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
    console.log('[Clean] Temp test files removed.');
    process.exit(0);
  });
});
