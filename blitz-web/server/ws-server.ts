/**
 * Real-time matchmaking + live match sync for VINEROX Blitz.
 * Run standalone: `npm run ws` (separate from the Next.js server).
 *
 * Protocol (JSON messages over one socket per player):
 *   -> { type: 'queue', profileId, name, flag, stake }
 *   <- { type: 'matched', matchId, seed, asset, opponent }
 *   <- { type: 'timeout' }                      // no human found, client falls back to bot via REST
 *   -> { type: 'tick', matchId, pnl }            // live score broadcast to the paired opponent
 *   <- { type: 'opponent_tick', pnl }
 *   -> { type: 'finish', matchId, outcome }
 *   <- { type: 'opponent_left' }
 */
import { WebSocketServer, type WebSocket } from 'ws';
import { ASSETS, BOT_FALLBACK_SECONDS } from '../src/lib/types';

const PORT = Number(process.env.BLITZ_WS_PORT ?? 4001);

interface QueuedPlayer {
  socket: WebSocket;
  profileId: string;
  name: string;
  flag: string;
  stake: number;
  timeout: ReturnType<typeof setTimeout>;
}

interface Room {
  matchId: string;
  players: [QueuedPlayer, QueuedPlayer];
}

const queue: QueuedPlayer[] = [];
const rooms = new Map<string, Room>();
const socketRoom = new Map<WebSocket, string>();

function send(socket: WebSocket, payload: unknown) {
  if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(payload));
}

function tryPair() {
  while (queue.length >= 2) {
    const a = queue.shift()!;
    const b = queue.shift()!;
    clearTimeout(a.timeout);
    clearTimeout(b.timeout);
    const matchId = `rt_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
    const seed = Math.floor(Math.random() * 2 ** 31);
    const asset = ASSETS[Math.floor(Math.random() * ASSETS.length)];
    rooms.set(matchId, { matchId, players: [a, b] });
    socketRoom.set(a.socket, matchId);
    socketRoom.set(b.socket, matchId);
    send(a.socket, { type: 'matched', matchId, seed, asset, opponent: { id: b.profileId, name: b.name, flag: b.flag, isBot: false } });
    send(b.socket, { type: 'matched', matchId, seed, asset, opponent: { id: a.profileId, name: a.name, flag: a.flag, isBot: false } });
  }
}

const wss = new WebSocketServer({ port: PORT });
console.log(`[blitz-ws] listening on ws://localhost:${PORT}`);

wss.on('connection', (socket) => {
  socket.on('message', (raw) => {
    let msg: Record<string, unknown>;
    try {
      msg = JSON.parse(String(raw));
    } catch {
      return;
    }

    if (msg.type === 'queue') {
      const player: QueuedPlayer = {
        socket,
        profileId: String(msg.profileId ?? ''),
        name: String(msg.name ?? 'Challenger'),
        flag: String(msg.flag ?? '🏳️'),
        stake: Number(msg.stake ?? 10),
        timeout: setTimeout(() => {
          const idx = queue.indexOf(player);
          if (idx >= 0) queue.splice(idx, 1);
          send(socket, { type: 'timeout' });
        }, BOT_FALLBACK_SECONDS * 1000),
      };
      queue.push(player);
      tryPair();
      return;
    }

    if (msg.type === 'tick' && typeof msg.matchId === 'string') {
      const room = rooms.get(msg.matchId);
      if (!room) return;
      const other = room.players.find((p) => p.socket !== socket);
      if (other) send(other.socket, { type: 'opponent_tick', pnl: msg.pnl });
      return;
    }

    if (msg.type === 'finish' && typeof msg.matchId === 'string') {
      rooms.delete(msg.matchId);
    }
  });

  socket.on('close', () => {
    const qIdx = queue.findIndex((p) => p.socket === socket);
    if (qIdx >= 0) {
      clearTimeout(queue[qIdx]!.timeout);
      queue.splice(qIdx, 1);
    }
    const matchId = socketRoom.get(socket);
    if (matchId) {
      const room = rooms.get(matchId);
      const other = room?.players.find((p) => p.socket !== socket);
      if (other) send(other.socket, { type: 'opponent_left' });
      rooms.delete(matchId);
      socketRoom.delete(socket);
    }
  });
});
