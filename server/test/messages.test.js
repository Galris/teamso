import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
process.env.USE_FIREBASE_EMULATORS = 'true';
process.env.FIREBASE_PROJECT_ID = 'demo-teamup-local';
process.env.FIREBASE_WEB_API_KEY = 'demo-test-key';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
const { db } = await import('../src/firebase/client.js');
const { createMessageService } = await import('../src/firebase/messages.js');
const collection = db.collection('test_messages_' + Date.now());
const service = createMessageService({ collection(name) { assert.equal(name, 'messages'); return collection; } });
after(async () => {
  const snapshot = await collection.get();
  if (snapshot.size) { const batch = db.batch(); snapshot.docs.forEach(doc => batch.delete(doc.ref)); await batch.commit(); }
  await db.terminate();
});

test('sendMessage validates text and stores authoritative fields with server timestamp', async () => {
  await assert.rejects(service.sendMessage('  ', 'uid', 'Nghi'), { code: 'INVALID_MESSAGE' });
  await assert.rejects(service.sendMessage('x'.repeat(2001), 'uid', 'Nghi'), { code: 'INVALID_MESSAGE' });
  const { id } = await service.sendMessage('  Hello TeamUp  ', 'uid-test', 'Nghi', 'https://example.com/avatar.png');
  const message = (await collection.doc(id).get()).data();
  assert.deepEqual(Object.keys(message).sort(), ['name','profilePicUrl','text','timestamp','uid']);
  assert.equal(message.text, 'Hello TeamUp'); assert.equal(message.uid, 'uid-test');
  assert.equal(message.profilePicUrl, 'https://example.com/avatar.png');
  assert.ok(message.timestamp instanceof Timestamp);
});

test('listenToMessages returns newest 50 in ascending timestamp order and can unsubscribe', async () => {
  const batch = db.batch();
  for (let i=0;i<55;i++) batch.set(collection.doc('ordered_'+i), { text: String(i), uid:'uid-test',name:'Nghi',profilePicUrl:'',timestamp:Timestamp.fromMillis(Date.now()+100000+i) });
  await batch.commit();
  let stop;
  const rows = await new Promise((resolve,reject) => {
    const timer=setTimeout(()=>reject(new Error('Listener timeout')),10000);
    stop=service.listenToMessages(data=>{clearTimeout(timer);resolve(data);},reject);
  });
  stop();
  assert.equal(rows.length,50); assert.equal(rows[0].text,'5'); assert.equal(rows.at(-1).text,'54');
  assert.ok(rows.every((row,i)=>i===0 || row.timestamp>=rows[i-1].timestamp));
});

test('two independent listeners both receive a new message without polling', async () => {
  const marker='realtime_'+Date.now();
  const stops=[];
  const pending = [1,2].map(()=>new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>reject(new Error('Realtime timeout')),10000);
    stops.push(service.listenToMessages(rows=>{if(rows.some(r=>r.text===marker)){clearTimeout(timer);resolve();}},reject));
  }));
  try {
    // Later than the ordered fixtures so the new message belongs to the current window.
    await collection.add({text:marker,uid:'uid-test',name:'Nghi',profilePicUrl:'',timestamp:Timestamp.fromMillis(Date.now()+200000)});
    await Promise.all(pending);
  } finally { stops.forEach(stop=>stop()); }
});
test('authenticated API streams SSE and ignores forged sender identity', async () => {
  const { auth, firebaseRest } = await import('../src/firebase/client.js');
  const { createApp } = await import('../src/app.js');
  const uid='chat_test_'+Date.now();
  const email=uid+'@example.com';
  const server=createApp().listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api`;
  let id, reader;
  try {
    assert.equal((await fetch(base+'/messages',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text:'Hi'})})).status,401);
    await auth.createUser({uid,email,password:'Test-chat-123'});
    await db.collection('users').doc(uid).set({username:uid,email,displayName:'Verified sender'});
    const tokens=await firebaseRest('accounts:signInWithPassword',{email,password:'Test-chat-123',returnSecureToken:true});
    const headers={Authorization:'Bearer '+tokens.idToken,'Content-Type':'application/json'};
    const stream=await fetch(base+'/messages/stream',{headers,signal:AbortSignal.timeout(15000)});
    assert.equal(stream.headers.get('content-type'),'text/event-stream; charset=utf-8');
    reader=stream.body.getReader();
    const response=await fetch(base+'/messages',{method:'POST',headers,body:JSON.stringify({text:'API realtime test',uid:'forged',name:'Fake'})});
    assert.equal(response.status,201); id=(await response.json()).id;
    const saved=(await db.collection('messages').doc(id).get()).data();
    assert.equal(saved.uid,uid); assert.equal(saved.name,'Verified sender');
    const decoder=new TextDecoder(); let buffer=''; let found=false;
    while(!found){const chunk=await reader.read();assert.equal(chunk.done,false);buffer+=decoder.decode(chunk.value,{stream:true});let end;while((end=buffer.indexOf('\n\n'))>=0){const frame=buffer.slice(0,end);buffer=buffer.slice(end+2);if(frame.startsWith('data: ')){const data=JSON.parse(frame.slice(6));found=data.messages?.some(message=>message.id===id)??false;if(found)break;}}}
    assert.ok(found);
  } finally {
    await reader?.cancel(); server.closeAllConnections(); await new Promise(resolve=>server.close(resolve));
    if(id)await db.collection('messages').doc(id).delete();
    await db.collection('users').doc(uid).delete();
    await auth.deleteUser(uid).catch(()=>{});
  }
});