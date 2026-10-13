const http = require('http');
const net = require('net');

const PORT = process.env.PORT || 5001;

const server = http.createServer((req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  if (req.url === '/health' || req.url === '/api/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok', message: 'Print bridge is running' }));
  }

  if (req.method !== 'POST') {
    res.writeHead(405, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ success: false, message: 'Method Not Allowed' }));
  }

  const chunks = [];
  req.on('data', (chunk) => chunks.push(chunk));
  req.on('end', () => {
    try {
      const body = Buffer.concat(chunks).toString('utf8');
      const payload = JSON.parse(body || '{}');
      const ip = (payload.ip_address || '192.168.1.51').trim();
      const port = parseInt(payload.port, 10) || 9100;

      let buffer;
      if (payload.raw_base64) {
        buffer = Buffer.from(payload.raw_base64, 'base64');
      } else if (Array.isArray(payload.raw_bytes)) {
        buffer = Buffer.from(payload.raw_bytes);
      } else {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ success: false, message: 'Missing raw_base64 or raw_bytes in payload.' }));
      }

      const socket = new net.Socket();
      let finished = false;

      const timer = setTimeout(() => {
        if (!finished) {
          finished = true;
          socket.destroy();
          res.writeHead(504, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: false,
            message: `Connection timed out. LAN printer at ${ip}:${port} did not answer within 5 seconds.`,
          }));
        }
      }, 5000);

      socket.once('error', (err) => {
        if (!finished) {
          finished = true;
          clearTimeout(timer);
          res.writeHead(502, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: false,
            message: `LAN printer socket error: ${err.message}`,
          }));
        }
      });

      socket.connect(port, ip, () => {
        if (!finished) {
          finished = true;
          clearTimeout(timer);
          socket.write(buffer, () => {
            socket.end();
          });
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            success: true,
            message: `Direct print sent successfully to LAN printer at ${ip}:${port}!`,
          }));
        }
      });
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ success: false, message: err.message || 'Internal error' }));
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`🖨️  Direct LAN Printer Bridge listening on http://localhost:${PORT}`);
});
