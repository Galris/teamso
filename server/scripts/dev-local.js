import 'dotenv/config';
import { spawn } from 'node:child_process';
const children = [];
const start = file => { const child = spawn(process.execPath, [file], { stdio: 'inherit', windowsHide: true }); children.push(child); return child; };
if (process.env.USE_FIREBASE_EMULATORS === 'true') {
  const ready = async () => { try { const r = await fetch('http://127.0.0.1:4400/emulators', { signal: AbortSignal.timeout(1000) }); const emulators = await r.json(); return !!(emulators.auth && emulators.firestore); } catch { return false; } };
  if (!await ready()) {
    const emulator = start('scripts/emulators.js');
    let available = false;
    for (let i = 0; i < 120; i++) {
      if (emulator.exitCode !== null) throw new Error('Firebase Emulator không khởi động được.');
      if (await ready()) { available = true; break; }
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    if (!available) throw new Error('Emulator khởi động quá lâu. Chạy npm run emulators để xem log.');
  }
}
const api = start('scripts/start-local.js');
let exporting = false;
function save() {
  if (exporting || process.env.USE_FIREBASE_EMULATORS !== 'true') return Promise.resolve();
  exporting = true;
  return new Promise(resolve => {
    const job = spawn(process.execPath, ['scripts/save-emulators.js'], { stdio: 'inherit', windowsHide: true });
    job.on('error', () => { exporting = false; resolve(); });
    job.on('exit', () => { exporting = false; resolve(); });
  });
}
const timer = setInterval(save, 60000);
api.on('exit', code => { clearInterval(timer); process.exitCode = code ?? 1; });
let stopping = false;
async function stop() { if (stopping) return; stopping = true; clearInterval(timer); await save(); for (const child of children) child.kill('SIGINT'); process.exit(0); }
process.on('SIGINT', stop); process.on('SIGTERM', stop);
