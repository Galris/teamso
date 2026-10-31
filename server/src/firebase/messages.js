import { FieldValue } from 'firebase-admin/firestore';
import { db } from './client.js';

const invalid = message => Object.assign(new Error(message), { status: 400, code: 'INVALID_MESSAGE' });

// A shared room for authenticated TeamUp users. Identity must come from verified auth.
export function createMessageService(database) {
  return {
    async sendMessage(text, userId, userName, userPhoto = '') {
      if (typeof text !== 'string' || !text.trim() || text.trim().length > 2000) {
        throw invalid('Tin nhắn cần từ 1 đến 2000 ký tự.');
      }
      if (typeof userId !== 'string' || !userId || typeof userName !== 'string' || !userName.trim()) {
        throw invalid('Thiếu thông tin người gửi.');
      }
      const photo = typeof userPhoto === 'string' && /^https:\/\//.test(userPhoto) ? userPhoto : '';
      const message = await database.collection('messages').add({
        text: text.trim(), uid: userId, name: userName.trim(), profilePicUrl: photo,
        timestamp: FieldValue.serverTimestamp(),
      });
      return { id: message.id };
    },
    listenToMessages(callback, onError = () => {}) {
      // limit(50) with ascending order would incorrectly return the OLDEST messages.
      return database.collection('messages').orderBy('timestamp', 'asc').limitToLast(50)
        .onSnapshot(snapshot => callback(snapshot.docs.map(doc => {
          const data = doc.data();
          return { id: doc.id, text: data.text, uid: data.uid, name: data.name,
            profilePicUrl: data.profilePicUrl ?? '', timestamp: data.timestamp?.toDate?.().toISOString() ?? null };
        })), onError);
    },
  };
}

export const { sendMessage, listenToMessages } = createMessageService(db);
