/**
 * Sijawara Chat WebSocket Server
 * 
 * Real-time messaging antara Wali Murid dan Guru Kelas.
 * Kompatibel dengan cPanel Node.js (Phusion Passenger).
 */

const http = require('http');
const https = require('https');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

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

// ═══════════════════════════════════════════════════════════════════════
// ── FCM Direct Push (Node.js langsung ke Google FCM API, tanpa PHP) ──
// ═══════════════════════════════════════════════════════════════════════

// Coba beberapa kemungkinan path service account (cPanel Passenger __dirname bisa beda)
const SA_FILENAME = 'firebase-service-account.json';
const FCM_SA_CANDIDATES = [
  path.join(__dirname, '../config', SA_FILENAME),               // server/websocket/../config/
  path.join(__dirname, '../../config', SA_FILENAME),             // jika __dirname = public_html/websocket
  path.join(__dirname, 'config', SA_FILENAME),                   // jika __dirname = public_html/
  path.join(__dirname, '../server/config', SA_FILENAME),         // jika __dirname diluar server/
  path.resolve('/home/pory3729/public_html/config', SA_FILENAME), // absolute cPanel path (fallback)
];

let FCM_SA_PATH = null;
for (const candidate of FCM_SA_CANDIDATES) {
  try {
    if (fs.existsSync(candidate)) {
      FCM_SA_PATH = candidate;
      break;
    }
  } catch (_) {}
}

// Log file di samping server.js (pasti writable)
const FCM_LOG_CANDIDATES = [
  path.join(__dirname, '../fcm_debug.log'),
  path.join(__dirname, 'fcm_debug.log'),
  '/tmp/sijawara_fcm_debug.log',
];
let FCM_LOG_PATH = FCM_LOG_CANDIDATES[0];
for (const lp of FCM_LOG_CANDIDATES) {
  try { fs.appendFileSync(lp, ''); FCM_LOG_PATH = lp; break; } catch (_) {}
}

let fcmServiceAccount = null;
let fcmAccessToken = null;
let fcmTokenExpiresAt = 0;

/**
 * Log ke console + file fcm_debug.log (agar bisa dicek di hosting).
 */
function fcmLog(msg) {
  const ts = new Date().toISOString().replace('T', ' ').substring(0, 19);
  const line = `[${ts}] ${msg}`;
  console.log(line);
  try { fs.appendFileSync(FCM_LOG_PATH, line + '\n'); } catch (_) {}
}

// Startup diagnostic
fcmLog(`[FCM] __dirname = ${__dirname}`);
fcmLog(`[FCM] SA candidates tried: ${FCM_SA_CANDIDATES.join(', ')}`);
fcmLog(`[FCM] SA found at: ${FCM_SA_PATH || 'NONE'}`);
fcmLog(`[FCM] Log path: ${FCM_LOG_PATH}`);

// Load service account saat startup
if (FCM_SA_PATH) {
  try {
    fcmServiceAccount = JSON.parse(fs.readFileSync(FCM_SA_PATH, 'utf8'));
    fcmLog(`[FCM] Service account loaded: project=${fcmServiceAccount.project_id}, email=${fcmServiceAccount.client_email}`);
  } catch (e) {
    fcmLog(`[FCM] GAGAL parse service account dari ${FCM_SA_PATH}: ${e.message}`);
  }
} else {
  fcmLog(`[FCM] ❌ Service account NOT FOUND di semua kandidat path!`);
  fcmLog(`[FCM] Pastikan firebase-service-account.json ada di folder config/ (sejajar websocket/)`);
}

/**
 * Base64url encode (tanpa padding).
 */
function base64url(data) {
  const str = typeof data === 'string' ? data : JSON.stringify(data);
  return Buffer.from(str)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Buat JWT dari service account credentials (RS256).
 */
function createFcmJwt() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url({ alg: 'RS256', typ: 'JWT' });
  const claims = base64url({
    iss: fcmServiceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const signInput = `${header}.${claims}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signInput);
  const signature = signer.sign(fcmServiceAccount.private_key)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  return `${signInput}.${signature}`;
}

/**
 * Dapatkan OAuth2 access token dari Google (cached 50 menit).
 */
function getFcmAccessToken() {
  return new Promise((resolve, reject) => {
    if (fcmAccessToken && Date.now() < fcmTokenExpiresAt) {
      return resolve(fcmAccessToken);
    }
    const jwt = createFcmJwt();
    const postBody = `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${jwt}`;
    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postBody),
      },
      timeout: 10000,
    }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          return reject(new Error(`OAuth2 HTTP ${res.statusCode}: ${data.substring(0, 300)}`));
        }
        try {
          const parsed = JSON.parse(data);
          fcmAccessToken = parsed.access_token;
          fcmTokenExpiresAt = Date.now() + 50 * 60 * 1000; // 50 menit
          fcmLog('[FCM] OAuth2 access token refreshed');
          resolve(fcmAccessToken);
        } catch (e) {
          reject(new Error(`OAuth2 JSON parse error: ${e.message}`));
        }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('OAuth2 timeout')); });
    req.write(postBody);
    req.end();
  });
}

/**
 * Kirim 1 FCM push ke 1 device token via FCM HTTP v1 API.
 */
function sendSingleFcm(projectId, accessToken, fcmPayload) {
  return new Promise((resolve) => {
    const body = JSON.stringify(fcmPayload);
    const req = https.request({
      hostname: 'fcm.googleapis.com',
      path: `/v1/projects/${projectId}/messages:send`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
      timeout: 10000,
    }, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => {
        resolve({ success: res.statusCode === 200, httpCode: res.statusCode, response: data });
      });
    });
    req.on('error', (err) => resolve({ success: false, httpCode: 0, response: err.message }));
    req.on('timeout', () => { req.destroy(); resolve({ success: false, httpCode: 0, response: 'timeout' }); });
    req.write(body);
    req.end();
  });
}

// Cache sender info agar tidak query berulang
const senderCache = new Map();
async function getSenderInfo(userId) {
  if (senderCache.has(userId)) return senderCache.get(userId);
  const [rows] = await pool.execute('SELECT name, role, avatar_url FROM users WHERE id = ? LIMIT 1', [userId]);
  if (rows.length === 0) return null;
  const avatarUrl = rows[0].avatar_url || '';
  // Resolve avatar URL jadi absolute
  let fullAvatarUrl = '';
  if (avatarUrl) {
    fullAvatarUrl = avatarUrl.startsWith('http') ? avatarUrl : `https://portal-smalka.com/${avatarUrl}`;
  }
  const info = { name: rows[0].name, role: rows[0].role, avatarUrl: fullAvatarUrl };
  senderCache.set(userId, info);
  setTimeout(() => senderCache.delete(userId), 5 * 60 * 1000); // cache 5 menit
  return info;
}

/**
 * Cek apakah user tertentu sedang online di WebSocket.
 */
function isReceiverOnline(userId) {
  const sockets = clients.get(userId);
  if (!sockets || sockets.size === 0) return false;
  for (const sock of sockets) {
    if (sock.readyState === 1) return true; // WebSocket.OPEN = 1
  }
  return false;
}

/**
 * Kirim FCM push notification LANGSUNG ke Google FCM API.
 * Tidak melalui PHP lagi — menghindari masalah SSL self-call di cPanel.
 * Dipanggil tanpa await (fire-and-forget) di message handler.
 */
async function sendFcmNotification(senderId, receiverId, message, attachmentType) {
  if (!fcmServiceAccount) {
    fcmLog(`[FCM] Service account not loaded, skip push ${senderId}→${receiverId}`);
    return;
  }

  try {
    // Ambil info pengirim
    const sender = await getSenderInfo(senderId);
    if (!sender) {
      fcmLog(`[FCM] Sender ${senderId} not found in DB`);
      return;
    }

    // Ambil semua FCM token penerima dari database
    const [tokenRows] = await pool.execute(
      'SELECT token FROM fcm_tokens WHERE user_id = ?',
      [receiverId]
    );
    if (tokenRows.length === 0) {
      fcmLog(`[FCM] No tokens for receiver ${receiverId}, skip push`);
      return;
    }

    // Tentukan body notifikasi
    let notifBody;
    if (attachmentType === 'image') {
      notifBody = '📷 Mengirim foto';
    } else if (attachmentType === 'document') {
      notifBody = '📄 Mengirim dokumen';
    } else if (message && message.trim()) {
      notifBody = message.length > 100 ? message.substring(0, 100) + '...' : message;
    } else {
      notifBody = 'Mengirim pesan';
    }

    // Dapatkan OAuth2 access token (cached)
    const accessToken = await getFcmAccessToken();
    const projectId = fcmServiceAccount.project_id;

    let sent = 0, failed = 0;
    for (const row of tokenRows) {
      const fcmPayload = {
        message: {
          token: row.token,
          notification: {
            title: sender.name,
            body: notifBody,
          },
          data: {
            type: 'chat',
            sender_id: String(senderId),
            sender_name: sender.name,
            sender_role: sender.role,
            sender_avatar: sender.avatarUrl || '',
            channel_id: 'chat_channel',
          },
          android: {
            priority: 'HIGH',
            notification: {
              channel_id: 'chat_channel',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
              default_sound: true,
              default_vibrate_timings: true,
              notification_priority: 'PRIORITY_HIGH',
            },
          },
        },
      };

      const result = await sendSingleFcm(projectId, accessToken, fcmPayload);
      if (result.success) {
        sent++;
      } else {
        failed++;
        fcmLog(`[FCM] FAILED token=${row.token.substring(0, 20)}... HTTP ${result.httpCode}: ${result.response.substring(0, 300)}`);
        // Hapus token yang sudah tidak valid
        if (result.response.includes('UNREGISTERED') || result.response.includes('NOT_FOUND')) {
          await pool.execute('DELETE FROM fcm_tokens WHERE token = ?', [row.token]);
          fcmLog(`[FCM] Cleaned invalid token for user ${receiverId}`);
        }
      }
    }

    fcmLog(`[FCM] Push ${senderId}(${sender.name})→${receiverId}: sent=${sent}, failed=${failed}`);
  } catch (err) {
    fcmLog(`[FCM] ERROR ${senderId}→${receiverId}: ${err.message}`);
  }
}

// ── HTTP Server (Passenger butuh ini) ──
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    service: 'Sijawara Chat WebSocket',
    version: '2.1-direct-fcm',
    clients: clients.size,
    fcm_ready: !!fcmServiceAccount,
    fcm_project: fcmServiceAccount ? fcmServiceAccount.project_id : null,
    fcm_sa_path: FCM_SA_PATH || 'NOT FOUND',
    fcm_log_path: FCM_LOG_PATH,
    __dirname: __dirname,
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

        const { receiver_id, message, attachment_type, attachment_url, attachment_name, attachment_size, reply_to_message_id } = data;
        if (!receiver_id || (!message && !attachment_url) || (message && message.trim() === '' && !attachment_url)) {
          ws.send(JSON.stringify({ type: 'error', message: 'receiver_id dan message/attachment diperlukan' }));
          return;
        }

        try {
          const aType = attachment_type || 'none';
          const aUrl = attachment_url || null;
          const aName = attachment_name || null;
          const aSize = attachment_size || null;
          const replyToMessageId = reply_to_message_id || null;
          const msgText = (message || '').trim();

          let replyPreview = null;
          let replySenderId = null;
          if (replyToMessageId) {
            const [replyRows] = await pool.execute(
              'SELECT sender_id, message, attachment_type FROM chat_messages WHERE id = ? LIMIT 1',
              [replyToMessageId]
            );
            if (replyRows.length > 0) {
              replySenderId = replyRows[0].sender_id;
              if (replyRows[0].attachment_type === 'image') {
                replyPreview = '📷 Foto';
              } else if (replyRows[0].attachment_type === 'document') {
                replyPreview = '📄 Dokumen';
              } else {
                replyPreview = replyRows[0].message || '';
              }
            }
          }

          // Simpan ke database
          const [result] = await pool.execute(
            'INSERT INTO chat_messages (sender_id, receiver_id, message, attachment_type, attachment_url, attachment_name, attachment_size, reply_to_message_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [authenticatedUserId, receiver_id, msgText, aType, aUrl, aName, aSize, replyToMessageId]
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
              reply_to_message_id: replyToMessageId,
              reply_preview: replyPreview,
              reply_sender_id: replySenderId,
              is_read: false,
              created_at: now,
            },
          };

          // Kirim ke pengirim (konfirmasi)
          sendToUser(authenticatedUserId, payload);

          // Kirim ke penerima (jika online di WS)
          sendToUser(receiver_id, payload);

          // Selalu kirim FCM push notification.
          // Jika penerima sedang di halaman chat → Flutter suppress notifikasi.
          // Jika penerima sedang di halaman lain / app background / killed → notifikasi muncul.
          sendFcmNotification(authenticatedUserId, receiver_id, msgText, aType);

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
            reply_to_message_id: data.reply_to_message_id || null,
            reply_preview: data.reply_preview || null,
            reply_sender_id: data.reply_sender_id || null,
            is_read: false,
            created_at: data.created_at || new Date().toISOString().replace('T', ' ').substring(0, 19),
          },
        };

        // Broadcast ke penerima via WS (real-time update)
        sendToUser(data.receiver_id, notifyPayload);

        // FCM backup: Jika penerima TIDAK online di WS, kirim FCM.
        // (PHP upload endpoint sudah kirim FCM, tapi ini sebagai safety net
        //  jika PHP FCM gagal dan receiver offline.)
        if (!isReceiverOnline(data.receiver_id)) {
          sendFcmNotification(
            authenticatedUserId,
            data.receiver_id,
            data.message || '',
            data.attachment_type || 'none'
          );
          console.log(`[Notify] ${authenticatedUserId} → ${data.receiver_id}: attachment + FCM (receiver offline)`);
        } else {
          console.log(`[Notify] ${authenticatedUserId} → ${data.receiver_id}: attachment (receiver online, skip FCM)`);
        }
        break;
      }

      // ── DELETE MESSAGE (broadcast soft-delete) ──
      case 'delete_message': {
        if (!authenticatedUserId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Belum autentikasi' }));
          return;
        }
        const { message_id: delMsgId, receiver_id: delReceiverId } = data;
        if (!delMsgId) break;

        // Broadcast ke pengirim dan penerima
        const deletedPayload = {
          type: 'message_deleted',
          data: { message_id: delMsgId },
        };
        sendToUser(authenticatedUserId, deletedPayload);
        if (delReceiverId) sendToUser(delReceiverId, deletedPayload);
        console.log(`[Delete] User ${authenticatedUserId} deleted msg ${delMsgId}`);
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

      // ── BROADCAST ANNOUNCEMENT (maklumat) ──
      case 'broadcast_announcement': {
        if (!authenticatedUserId) {
          ws.send(JSON.stringify({ type: 'error', message: 'Belum autentikasi' }));
          return;
        }

        const { maklumat_id, judul, deskripsi, prioritas, target_audience, icon } = data;
        if (!maklumat_id || !judul) {
          ws.send(JSON.stringify({ type: 'error', message: 'Data maklumat tidak lengkap' }));
          return;
        }

        try {
          // Cari semua user_id siswa (dan ortu jika target mencakup) yang terkoneksi
          let targetUserIds = [];

          if (target_audience === 'siswa' || target_audience === 'keduanya') {
            const [students] = await pool.execute(
              'SELECT u.id FROM users u JOIN students s ON s.user_id = u.id WHERE u.is_active = 1'
            );
            targetUserIds.push(...students.map(r => r.id));
          }

          if (target_audience === 'orang_tua' || target_audience === 'keduanya') {
            const [parents] = await pool.execute(
              "SELECT id FROM users WHERE role = 'orang_tua' AND is_active = 1"
            );
            targetUserIds.push(...parents.map(r => r.id));
          }

          // Deduplicate
          targetUserIds = [...new Set(targetUserIds)];

          const announcementPayload = {
            type: 'new_announcement',
            data: {
              maklumat_id,
              judul,
              deskripsi: (deskripsi || '').substring(0, 200),
              prioritas: prioritas || 'Sedang',
              target_audience: target_audience || 'keduanya',
              icon: icon || 'campaign',
              sender_id: authenticatedUserId,
              created_at: new Date().toISOString().replace('T', ' ').substring(0, 19),
            },
          };

          let delivered = 0;
          for (const uid of targetUserIds) {
            if (clients.has(uid)) {
              sendToUser(uid, announcementPayload);
              delivered++;
            }
          }

          ws.send(JSON.stringify({
            type: 'announcement_sent',
            data: { maklumat_id, total_targets: targetUserIds.length, delivered },
          }));

          console.log(`[Announcement] User ${authenticatedUserId} broadcast "${judul}" to ${delivered}/${targetUserIds.length} online users`);
        } catch (err) {
          console.error('[Announcement DB Error]', err);
          ws.send(JSON.stringify({ type: 'error', message: 'Gagal broadcast pengumuman' }));
        }
        break;
      }

      // ── PIN MESSAGE (broadcast to both users) ──
      case 'pin_message': {
        if (!authenticatedUserId) return;
        const { partner_id: pinPartner, message_id: pinMsgId, pin_preview, pin_sender_id, pinned_by_name } = data;
        if (!pinPartner || !pinMsgId) break;

        const pinPayload = {
          type: 'message_pinned',
          data: {
            message_id: pinMsgId,
            pinned_by: authenticatedUserId,
            pinned_by_name: pinned_by_name || '',
            pin_preview: pin_preview || '',
            pin_sender_id: pin_sender_id || null,
          },
        };
        sendToUser(authenticatedUserId, pinPayload);
        sendToUser(pinPartner, pinPayload);
        console.log(`[Pin] User ${authenticatedUserId} pinned msg ${pinMsgId} in conv with ${pinPartner}`);
        break;
      }

      // ── UNPIN MESSAGE (broadcast to both users) ──
      case 'unpin_message': {
        if (!authenticatedUserId) return;
        const { partner_id: unpinPartner } = data;
        if (!unpinPartner) break;

        const unpinPayload = {
          type: 'message_unpinned',
          data: { unpinned_by: authenticatedUserId },
        };
        sendToUser(authenticatedUserId, unpinPayload);
        sendToUser(unpinPartner, unpinPayload);
        console.log(`[Unpin] User ${authenticatedUserId} unpinned in conv with ${unpinPartner}`);
        break;
      }

      // ── PING/PONG (heartbeat) ──
      case 'ping': {
        ws.send(JSON.stringify({ type: 'pong' }));
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
