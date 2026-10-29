import { spawn, execFileSync } from 'node:child_process';
if (process.platform === 'win32') {
  const short = execFileSync('cmd.exe', ['/d','/s','/c','for %I in (.) do @echo %~fsI'], { encoding: 'utf8', windowsHide: true }).trim();
  if (short) process.chdir(short);
}
const child = spawn(process.env.ComSpec || 'cmd.exe', ['/d','/s','/c','firebase emulators:export .local/firebase-data --force --project demo-teamup-local --config firebase.json'], { stdio: 'inherit', windowsHide: true });
child.on('exit', code => process.exit(code ?? 1));
