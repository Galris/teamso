import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
process.env.USE_FIREBASE_EMULATORS = 'true';
process.env.FIREBASE_PROJECT_ID = 'demo-teamup-workspace';
process.env.FIREBASE_WEB_API_KEY = 'demo-test-key';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9199';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180';
const { createApp } = await import('../src/app.js');
const { db, auth } = await import('../src/firebase/client.js');
const app = createApp();
const pid = `workspace_${Date.now()}`;
const project = db.collection('projects').doc(pid);
const users = {};
const api = (role, method, path) => request(app)[method](`/api/projects/${pid}/workspace${path}`).set('Authorization', `Bearer ${users[role].token}`);
const client = (role, method, path, body) => fetch(`http://127.0.0.1:8180/v1/projects/demo-teamup-workspace/databases/(default)/documents/${path}`, {
  method, headers: { 'Content-Type': 'application/json', ...(role ? { Authorization: `Bearer ${users[role].token}` } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}),
});
before(async () => {
  for (const role of ['leader', 'member', 'other', 'outsider']) {
    const response = await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-test-key', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `${pid}_${role}@example.com`, password: 'Workspace-test-123', returnSecureToken: true }),
    });
    const data = await response.json();
    assert.ok(data.idToken, JSON.stringify(data));
    users[role] = { uid: data.localId, token: data.idToken };
    await db.doc(`users/${data.localId}`).set({ username: role, displayName: role, email: `${pid}_${role}@example.com` });
  }
  await project.set({ ownerId: users.leader.uid, memberIds: [users.member.uid, users.other.uid] });
  for (const role of ['leader', 'member', 'other']) await project.collection('members').doc(users[role].uid).set({ role: role === 'leader' ? 'leader' : 'member' });
});
after(async () => {
  await db.recursiveDelete(project);
  for (const u of Object.values(users)) { await db.recursiveDelete(db.doc(`users/${u.uid}`)); await auth.deleteUser(u.uid); }
  await db.terminate();
});
test('workspace: authenticated membership, strict inputs and creator/leader deletion', async () => {
  await request(app).post(`/api/projects/${pid}/workspace/documents`).send({label:'x'}).expect(401);
  await api('outsider', 'post', '/documents').send({label:'x'}).expect(403);
  for (const data of [{label:''},{label:'x',url:'javascript:alert(1)'},{label:'x',url:'https://user:pass@example.com'}, {label:'x',createdBy:'forged'}, {label:'x'.repeat(201)}]) {
    await api('member','post','/documents').send(data).expect(400);
  }
  const doc = (await api('member','post','/documents').send({label:'Tài liệu',url:'https://example.com'}).expect(201)).body.id;
  assert.equal((await project.collection('documents').doc(doc).get()).data().createdBy, users.member.uid);
  await api('other','delete',`/documents/${doc}`).expect(403);
  await api('member','delete',`/documents/${doc}`).expect(200);
  const second = (await api('member','post','/documents').send({label:'No URL'}).expect(201)).body.id;
  await api('leader','delete',`/documents/${second}`).expect(200);
  await api('leader','delete',`/documents/${second}`).expect(404);
});
test('meetings: timestamps, future range, required join link and deletion', async () => {
  const startsAt=new Date(Date.now()+86400000).toISOString(), endsAt=new Date(Date.now()+90000000).toISOString(), meetUrl='https://meet.google.com/abc-defg-hij';
  for(const body of [{label:'x'},{label:'x',startsAt,endsAt:startsAt},{label:'x',startsAt:'invalid',endsAt},{label:'x',startsAt:'2020-01-01T00:00:00Z',endsAt:'2020-01-01T01:00:00Z'},{label:'x',startsAt,endsAt},{label:'x',startsAt,endsAt,meetUrl:''},{label:'x',startsAt,endsAt,meetUrl:'meet.google.com/abc'},{label:'x',startsAt,endsAt,meetUrl:'javascript:alert(1)'}]) await api('member','post','/meetings').send(body).expect(400);
  const row=(await api('member','post','/meetings').send({label:'Họp thử',startsAt,endsAt,meetUrl}).expect(201)).body.id;
  const saved=(await project.collection('meetings').doc(row).get()).data();
  assert.equal(saved.startsAt.toDate().toISOString(),startsAt);
  assert.equal(saved.meetUrl,meetUrl);
  await api('other','delete',`/meetings/${row}`).expect(403);
  await api('leader','delete',`/meetings/${row}`).expect(200);
});
test('votes: multi-select, replacement, withdraw, range, unauthorized access and recursive cleanup', async () => {
  for(const options of [['one'],['A',' a '],Array(21).fill('A')]) await api('member','post','/votes').send({question:'Q',options}).expect(400);
  for(const kind of ['poll','MEETING',123]) await api('member','post','/votes').send({question:'Q',options:['A','B'],kind}).expect(400);
  const vote=(await api('member','post','/votes').send({question:'Question',options:['A','B','C']}).expect(201)).body.id;
  assert.equal((await project.collection('votes').doc(vote).get()).data().kind,'general');
  const ref=project.collection('votes').doc(vote), ballot=ref.collection('ballots').doc(users.member.uid);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[0,1,1]}).expect(200);
  assert.deepEqual((await ballot.get()).data().options,[0,1]);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[2]}).expect(200);
  assert.deepEqual((await ballot.get()).data().options,[2]);
  for(const options of [[-1],[3],[0.5],['1']]) await api('member','put',`/votes/${vote}/ballot`).send({options}).expect(400);
  await api('outsider','put',`/votes/${vote}/ballot`).send({options:[0]}).expect(403);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[]}).expect(200);
  assert.equal((await ballot.get()).exists,false);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[0,2]}).expect(200);
  await api('other','delete',`/votes/${vote}`).expect(403);
  await api('leader','delete',`/votes/${vote}`).expect(200);
  assert.equal((await ref.get()).exists,false);
  assert.equal((await ref.collection('ballots').get()).size,0);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[0]}).expect(404);
  assert.equal((await ref.collection('ballots').get()).size,0);
});
test('meeting votes keep a When2meet sized grid and vote indexes stay in range', async () => {
  const slots=Array.from({length:32},(_,i)=>`Khung ${i+1}`);
  await api('member','post','/votes').send({question:'Họp tuần sau',kind:'meeting',options:Array.from({length:61},(_,i)=>`S${i}`)}).expect(400);
  const vote=(await api('member','post','/votes').send({question:'Họp tuần sau',kind:'meeting',options:slots}).expect(201)).body.id;
  const ref=project.collection('votes').doc(vote), ballot=ref.collection('ballots').doc(users.member.uid);
  assert.equal((await ref.get()).data().kind,'meeting');
  await api('member','put',`/votes/${vote}/ballot`).send({options:[0,15,31]}).expect(200);
  assert.deepEqual((await ballot.get()).data().options,[0,15,31]);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[32]}).expect(400);
  await api('member','put',`/votes/${vote}/ballot`).send({options:[0,1,1,2]}).expect(200);
  assert.deepEqual((await ballot.get()).data().options,[0,1,2]);
  await api('leader','delete',`/votes/${vote}`).expect(200);
});
test('concurrent vote and deletion cannot leave orphan ballots', async () => {
  const vote=(await api('leader','post','/votes').send({question:'Race',options:['A','B']}).expect(201)).body.id;
  const [deleted,voted]=await Promise.all([api('leader','delete',`/votes/${vote}`),api('member','put',`/votes/${vote}/ballot`).send({options:[0]})]);
  assert.equal(deleted.status,200); assert.ok([200,404].includes(voted.status));
  assert.equal((await project.collection('votes').doc(vote).collection('ballots').get()).size,0);
});
test('Firestore Rules: member realtime reads, outsider/anonymous denial, all direct mutations denied, orphan reads denied', async () => {
  const path=`projects/${pid}/documents/rules-test`;
  await db.doc(path).set({label:'Rules',createdBy:users.member.uid});
  assert.equal((await client('member','GET',path)).status,200);
  for(const role of [null,'outsider']) assert.equal((await client(role,'GET',path)).status,403);
  for(const collection of ['documents','meetings','votes']) {
    const p=`projects/${pid}/${collection}/forged`;
    const payload={fields:{label:{stringValue:'x'},createdBy:{stringValue:users.leader.uid}}};
    for(const role of [null,'outsider','member','leader']) assert.equal((await client(role,'PATCH',p,payload)).status,403);
  }
  for(const method of ['PATCH','DELETE']) assert.equal((await client('member',method,path,method==='PATCH'?{fields:{label:{integerValue:'1'}}}:null)).status,403);
  const orphan=`projects/${pid}/votes/missing/ballots/${users.member.uid}`;
  await db.doc(orphan).set({options:[0]});
  assert.equal((await client('member','GET',orphan)).status,403);
  assert.equal((await client('member','PATCH',orphan,{fields:{options:{arrayValue:{values:[{integerValue:'0'}]}}}})).status,403);
});

test('append options preserves ballots and handles concurrent additions', async () => {
  const vote=(await api('member','post','/votes').send({question:'Append',options:['A','B']}).expect(201)).body.id;
  await api('member','put',`/votes/${vote}/ballot`).send({options:[1]}).expect(200);
  await api('outsider','post',`/votes/${vote}/options`).send({option:'C'}).expect(403);
  for (const option of ['', ' a ', 'x'.repeat(121)]) await api('member','post',`/votes/${vote}/options`).send({option}).expect(400);
  const replies=await Promise.all(['C','D'].map(option=>api('other','post',`/votes/${vote}/options`).send({option})));
  assert.deepEqual(replies.map(r=>r.status),[201,201]);
  const ref=project.collection('votes').doc(vote);
  const options=(await ref.get()).data().options;
  assert.deepEqual(options.slice(0,2),['A','B']);
  assert.ok(options.includes('C') && options.includes('D'));
  assert.deepEqual((await ref.collection('ballots').doc(users.member.uid).get()).data().options,[1]);
  await ref.update({options:Array.from({length:20},(_,i)=>String(i))});
  await api('member','post',`/votes/${vote}/options`).send({option:'extra'}).expect(400);
  await api('leader','delete',`/votes/${vote}`).expect(200);
  await api('member','post',`/votes/${vote}/options`).send({option:'E'}).expect(404);
});
