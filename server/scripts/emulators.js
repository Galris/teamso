import { spawn, execFileSync } from 'node:child_process';
if (process.platform === 'win32') { const short = execFileSync('cmd.exe', ['/d', '/s', '/c', 'for %I in (.) do @echo %~fsI'], { encoding: 'utf8', windowsHide: true }).trim(); if (short) process.chdir(short); }
import { existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
// Use Android Studio's bundled Java >=21 without changing system JAVA_HOME.
const androidJdk = 'C:/Program Files/Android/Android Studio/jbr';
if (existsSync(join(androidJdk, 'bin/java.exe'))) {
  process.env.JAVA_HOME = androidJdk;
  process.env.PATH = join(androidJdk, 'bin') + ';' + process.env.PATH;
}
mkdirSync('.local/firebase-data', { recursive: true });
const command = 'firebase emulators:start --project demo-teamup-local --only auth,firestore --config firebase.json --import .local/firebase-data --export-on-exit .local/firebase-data';
const child = spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', command], { stdio: 'inherit', windowsHide: true, env: { ...process.env, FIREBASE_CLI_DISABLE_USAGE_REPORTING: 'true' } });
child.on('exit', code => process.exit(code ?? 1));
