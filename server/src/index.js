import { createApp } from './app.js';
const server = createApp().listen(Number(process.env.PORT || 3000), '127.0.0.1', () => console.log('TeamUp API: Firebase Authentication + Cloud Firestore'));
process.on('SIGINT', () => server.close(() => process.exit(0)));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
