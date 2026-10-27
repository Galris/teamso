import express from 'express';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createApp } from '../src/app.js';
import { db, usingEmulators } from '../src/firebase/client.js';
await db.collection('_health').limit(1).get();
const api = createApp().listen(Number(process.env.PORT || 3000), '127.0.0.1');
const webRoot = fileURLToPath(new URL('../../build/web/', import.meta.url));
let web;
if (existsSync(webRoot + '/index.html')) {
  const frontend = express();
  frontend.use(express.static(webRoot, { setHeaders: res => res.set('Cache-Control', 'no-store') }));
  web = frontend.listen(5200, '127.0.0.1', () => console.log(`TeamUp: http://127.0.0.1:5200 | Firebase ${usingEmulators ? 'Emulator (LOCAL)' : 'CLOUD'}`));
}
async function stop() { web?.close(); api.close(async () => { await db.terminate(); process.exit(0); }); }
process.on('SIGTERM', stop); process.on('SIGINT', stop);
