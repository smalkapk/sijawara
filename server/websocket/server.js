/**
 * Sijawara Chat WebSocket Server
 * 
 * Real-time messaging antara Wali Murid dan Guru Kelas.
 * Kompatibel dengan cPanel Node.js (Phusion Passenger).
 */

const http = require('http');
const path = require('path');

// Load .env jika ada (opsional, cPanel env vars sudah cukup)
try { require('dotenv').config({ path: path.join(__dirname, '.env') }); } catch(e) {}

const WebSocket = require('ws');
const mysql = require('mysql2/promise');

// ── Tracked clients ──
const clients = new Map(); // user_id → Set<WebSocket>

// ── Database Pool ──
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'pory3729_admin',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'pory3729_smalka',
  waitForConnections: true,
  connectionLimit: 10,
  charset: 'utf8mb4',
});

// ── HTTP Server (Passenger butuh ini) ──
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    service: 'Sijawara Chat WebSocket',
    clients: clients.size,
    node: process.version,
    uptime: Math.floor(process.uptime()),
  }));
});

// ── WebSocket Server (attach ke HTTP server) ──
const wss = new WebSocket.Server({ server });

// ── Start server ──
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`[Chat WS] Server running on port ${PORT}`);
});

wss.on('connection', (ws) => {
  let authenticatedUserId = null;

  ws.on('message', async (raw) => {
    let data;
    try {
      data = JSON.parse(raw.toString());
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid JSON' }));
      return;
    }

    switch (data.type) {

      // ── AUTH ──
      case 'auth': {
        const token = data.token;
        if (!token) {
          ws.send(JSON.stringify({ type: 'error', message: 'Token diperlukan' }));
          return;
        }

        // Decode token (format: base64(user_id).random_hex)
        const parts = token.split('.');
        if (parts.length < 1) {
          ws.send(JSON.stringify({ type: 'auth_fail', message: 'Token tidak valid' }));
          return;
        }
        const userId = parseInt(Buffer.from(parts[0], 'base64').toString(), 10);
        if (!userId || userId <= 0) {
          ws.send(JSON.stringify({ type: 'auth_fail', message: 'Token tidak valid' }));
          return;
        }

        // Verifikasi user ada di database
        try {
          const [rows] = await pool.execute(
            'SELECT id, name, role FROM users WHERE id = ? AND is_active = 1',
            [userId]
          );
          if (rows.length === 0) {
            ws.send(JSON.stringify({ type: 'auth_fail', message: 'User tidak ditemukan' }));
            return;
          }

          authenticatedUserId = userId;
          
          // Simpan ke clients map
          if (!clients.has(userId)) {
            clients.set(userId, new Set());
          }
          clients.get(userId).add(ws);

          ws.send(JSON.stringify({
            type: 'auth_ok',
            user_id: userId,
            name: rows[0].name,
            role: rows[0].role,
          }));

          console.log(`[Auth] User ${userId} (${rows[0].name}) connected`);
        } catch (err) {
          console.error('[Auth DB Error]', err);
          ws.send(JSON.stringify({ type: 'error', message: 'Database error' }));
        }
        break;
      }

      // ── SEND MESSAGE ──
      case 'message': {
        if (!authenticatedUserId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Belum autentikasi' }));
          return;
        }

        const { receiver_id, message, attachment_type, attachment_url, attachment_name, attachment_size } = data;
        if (!receiver_id || (!message && !attachment_url) || (message && message.trim() === '' && !attachment_url)) {
          ws.send(JSON.stringify({ type: 'error', message: 'receiver_id dan message/attachment diperlukan' }));
          return;
        }

        try {
          const aType = attachment_type || 'none';
          const aUrl = attachment_url || null;
          const aName = attachment_name || null;
          const aSize = attachment_size || null;
          const msgText = (message || '').trim();

          // Simpan ke database
          const [result] = await pool.execute(
            'INSERT INTO chat_messages (sender_id, receiver_id, message, attachment_type, attachment_url, attachment_name, attachment_size) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [authenticatedUserId, receiver_id, msgText, aType, aUrl, aName, aSize]
          );

          const msgId = result.insertId;
          const now = new Date().toISOString().replace('T', ' ').substring(0, 19);

          const payload = {
            type: 'new_message',
            data: {
              id: msgId,
              sender_id: authenticatedUserId,
              receiver_id: receiver_id,
              message: msgText,
              attachment_type: aType,
              attachment_url: aUrl,
              attachment_name: aName,
              attachment_size: aSize,
              is_read: false,
              created_at: now,
            },
          };

          // Kirim ke pengirim (konfirmasi)
          sendToUser(authenticatedUserId, payload);

          // Kirim ke penerima (jika online)
          sendToUser(receiver_id, payload);

          console.log(`[Msg] ${authenticatedUserId} → ${receiver_id}: ${aType !== 'none' ? `[${aType}] ` : ''}${(message || '').substring(0, 50)}`);
        } catch (err) {
          console.error('[Message DB Error]', err);
          ws.send(JSON.stringify({ type: 'error', message: 'Gagal mengirim pesan' }));
        }
        break;
      }

      // ── MARK READ ──
      case 'read': {
        if (!authenticatedUserId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Belum autentikasi' }));
          return;
        }

        const { partner_id } = data;
        if (!partner_id) {
          ws.send(JSON.stringify({ type: 'error', message: 'partner_id diperlukan' }));
          return;
        }

        try {
          await pool.execute(
            'UPDATE chat_messages SET is_read = 1 WHERE sender_id = ? AND receiver_id = ? AND is_read = 0',
            [partner_id, authenticatedUserId]
          );

          // Beritahu partner bahwa pesan sudah dibaca
          sendToUser(partner_id, {
            type: 'messages_read',
            data: { reader_id: authenticatedUserId },
          });

          console.log(`[Read] ${authenticatedUserId} read messages from ${partner_id}`);
        } catch (err) {
          console.error('[Read DB Error]', err);
        }
        break;
      }

      // ── NOTIFY ATTACHMENT (broadcast only, no DB insert) ──
      case 'notify': {
        if (!authenticatedUserId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Belum autentikasi' }));
          return;
        }

        const notifyPayload = {
          type: 'new_message',
          data: {
            id: data.id,
            sender_id: authenticatedUserId,
            receiver_id: data.receiver_id,
            message: data.message || '',
            attachment_type: data.attachment_type || 'none',
            attachment_url: data.attachment_url || null,
            attachment_name: data.attachment_name || null,
            attachment_size: data.attachment_size || null,
            is_read: false,
            created_at: data.created_at || new Date().toISOString().replace('T', ' ').substring(0, 19),
          },
        };

        // Hanya broadcast ke penerima, TANPA insert ke DB
        sendToUser(data.receiver_id, notifyPayload);
        console.log(`[Notify] ${authenticatedUserId} → ${data.receiver_id}: attachment notification`);
        break;
      }

      // ── TYPING INDICATOR ──
      case 'typing': {
        if (!authenticatedUserId) return;
        const { partner_id: typingPartner, is_typing } = data;
        if (!typingPartner) return;

        sendToUser(typingPartner, {
          type: 'typing',
          data: { user_id: authenticatedUserId, is_typing: !!is_typing },
        });
        break;
      }

      default:
        ws.send(JSON.stringify({ type: 'error', message: `Unknown type: ${data.type}` }));
    }
  });

  ws.on('close', () => {
    if (authenticatedUserId && clients.has(authenticatedUserId)) {
      clients.get(authenticatedUserId).delete(ws);
      if (clients.get(authenticatedUserId).size === 0) {
        clients.delete(authenticatedUserId);
      }
      console.log(`[Disconnect] User ${authenticatedUserId}`);
    }
  });

  ws.on('error', (err) => {
    console.error('[WS Error]', err.message);
  });
});

/**
 * Kirim payload JSON ke semua koneksi user tertentu
 */
function sendToUser(userId, payload) {
  const sockets = clients.get(userId);
  if (!sockets) return;

  const msg = JSON.stringify(payload);
  for (const sock of sockets) {
    if (sock.readyState === WebSocket.OPEN) {
      sock.send(msg);
    }
  }
}

// ── Graceful shutdown ──
process.on('SIGINT', () => {
  console.log('[Chat WS] Shutting down...');
  wss.close(() => {
    server.close(() => {
      pool.end();
      process.exit(0);
    });
  });
});
