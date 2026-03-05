/**
 * app.js — Entry point untuk cPanel Phusion Passenger
 */
try {
  require('./server.js');
} catch (err) {
  // Kalau server.js crash, tetap jalankan HTTP agar tidak 503
  const http = require('http');
  const errServer = http.createServer((req, res) => {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message, stack: err.stack }));
  });
  errServer.listen(process.env.PORT || 3000);
  console.error('[FATAL]', err);
}
