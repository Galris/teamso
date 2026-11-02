import {before, after, test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import request from 'supertest';
Object.assign(process.env, {USE_FIREBASE_EMULATORS:'true', FIREBASE_PROJECT_ID:'demo-teamup-workspace', FIREBASE_WEB_API_KEY:'demo-test-key', FIREBASE_AUTH_EMULATOR_HOST:'127.0.0.1:9199', FIRESTORE_EMULATOR_HOST:'127.0.0.1:8180'});
const {createApp} = await import('../src/app.js');
const {db, auth} = await import('../src/firebase/client.js');
const sends = [];
let failPush = false;
const app = createApp({messaging:{async sendEachForMulticast(message) {
  sends.push(message);
  if (failPush) throw Object.assign(new Error('Unavailable'), {code:'messaging/server-unavailable'});
  return {responses:message.tokens.map(token => token.endsWith('expired') ? {success:false,error:{code:'messaging/registration-token-not-registered'}} : {success:true})};
}}});
const pid = `notifications_${Date.now()}`;
const project = db.doc(`projects/${pid}`), users = {};
const inbox = role => db.collection(`users/${users[role].uid}/notifications`);
const call = (role, method, path) => request(app)[method](`/api${path}`).set('Authorization',`Bearer ${users[role].token}`);
const token = `${pid}_device_registration_token`;
const device = db.doc(`_pushDevices/${createHash('sha256').update(token).digest('hex')}`);
before(async () => {
  for (const role of ['leader','member','outsider','unrelated']) {
    const data = await (await fetch('http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-test-key',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:`${pid}_${role}@example.com`,password:'Notifications-123',returnSecureToken:true})})).json();
    assert.ok(data.idToken);
    users[role]={uid:data.localId,token:data.idToken};
    await db.doc(`users/${data.localId}`).set({username:role,email:`${pid}_${role}@example.com`});
  }
  await project.set({name:'QA dự án thông báo', joinCode:pid.toUpperCase(), ownerId:users.leader.uid,memberIds:[users.leader.uid,users.member.uid],totalTasks:0,completedTasks:0});
  await db.doc(`usernames/${pid}_outsider`).set({uid:users.outsider.uid});
  for(const role of ['leader','member']) await project.collection('members').doc(users[role].uid).set({role});
});
after(async () => {
  await db.recursiveDelete(project); await device.delete();
  await db.doc(`usernames/${pid}_outsider`).delete();
  for (const u of Object.values(users)) {
    const devices=await db.collection('_pushDevices').where('uid','==',u.uid).get();
    await Promise.all(devices.docs.map(d=>d.ref.delete()));
    await db.recursiveDelete(db.doc(`users/${u.uid}`)); await auth.deleteUser(u.uid);
  }
  await db.terminate();
});
test('device registration requires auth and valid token; another user cannot unsubscribe it',async () => {
  await request(app).put('/api/notifications/device').send({token}).expect(401);
  await call('member','put','/notifications/device').send({token:'bad'}).expect(400);
  await call('member','put','/notifications/device').send({token}).expect(200);
  assert.equal((await device.get()).data().uid,users.member.uid);
  await call('outsider','delete','/notifications/device').send({token}).expect(200);
  assert.equal((await device.get()).exists,true);
});
test('assignment creates one persisted notification and one FCM message; updates target recipients',async () => {
  const task=(await call('leader','post',`/projects/${pid}/tasks`).send({title:'QA thông báo',assigneeIds:[users.member.uid,users.member.uid]}).expect(201)).body.task;
  assert.equal((await inbox('member').get()).size,1);
  assert.equal((await inbox('outsider').get()).size,0);
  assert.equal(sends.length,1);
  assert.equal(sends[0].data.targetId,task.id);
  assert.deepEqual(sends[0].tokens,[token]);
  await call('member','patch',`/projects/${pid}/tasks/${task.id}`).send({status:'in_progress'}).expect(200);
  assert.equal((await inbox('leader').get()).size,1);
  await call('leader','patch',`/projects/${pid}/tasks/${task.id}`).send({title:'Tên mới'}).expect(200);
  assert.equal((await inbox('member').get()).size,2);
  await call('outsider','patch',`/projects/${pid}/tasks/${task.id}`).send({status:'completed'}).expect(403);
  assert.equal((await inbox('member').get()).size,2);
});
test('new meetings and polls notify members once, exclude actor and outsiders, persist if FCM fails',async () => {
  failPush=true;
  await call('leader','post',`/projects/${pid}/workspace/votes`).send({question:'QA Vote',options:['A','B']}).expect(201);
  const rows=await inbox('member').get();
  assert.equal(rows.size,3);
  assert.equal(rows.docs.filter(d=>d.data().type==='vote').length,1);
  failPush=false;
  await call('leader','post',`/projects/${pid}/workspace/meetings`).send({label:'QA Họp',startsAt:new Date(Date.now()+86400000).toISOString(),endsAt:new Date(Date.now()+90000000).toISOString()}).expect(201);
  assert.equal((await inbox('member').get()).size,4);
  assert.equal((await inbox('leader').get()).size,1);
  assert.equal((await inbox('outsider').get()).size,0);
});
test('private inbox rules: owner may mark read; cannot forge content or read device tokens',async () => {
  const n=(await inbox('member').get()).docs[0];
  const rest=async (role,method,path,body)=>fetch(`http://127.0.0.1:8180/v1/projects/demo-teamup-workspace/databases/(default)/documents/${path}`,{method,headers:{Authorization:`Bearer ${users[role].token}`,'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});
  assert.equal((await rest('member','GET',n.ref.path)).status,200);
  assert.equal((await rest('outsider','GET',n.ref.path)).status,403);
  assert.equal((await rest('member','PATCH',`${n.ref.path}?updateMask.fieldPaths=read`,{fields:{read:{booleanValue:true}}})).status,200);
  assert.equal((await rest('member','PATCH',`${n.ref.path}?updateMask.fieldPaths=title`,{fields:{title:{stringValue:'forged'}}})).status,403);
  assert.equal((await rest('member','GET',device.path)).status,403);
  assert.equal((await rest('member','PATCH',device.path,{fields:{token:{stringValue:'forged'}}})).status,403);
});
test('unsubscribe removes device and prevents future pushes',async () => {
  await call('member','delete','/notifications/device').send({token}).expect(200);
  assert.equal((await device.get()).exists,false);
  const before=sends.length;
  await call('leader','post',`/projects/${pid}/workspace/votes`).send({question:'No push',options:['A','B']}).expect(201);
  assert.equal(sends.length,before);
  assert.equal((await inbox('member').get()).size,5);
});

test('adding a member atomically notifies only the new member; concurrent duplicate adds do not resend',async () => {
  const path=`/projects/${pid}/members`, username=`${pid}_outsider`, newToken=`${pid}_new_member_device`;
  await call('outsider','put','/notifications/device').send({token:newToken}).expect(200);
  const memberCount=(await inbox('member').get()).size, leaderCount=(await inbox('leader').get()).size, sent=sends.length;
  await request(app).post(`/api${path}`).send({username}).expect(401);
  await call('member','post',path).send({username}).expect(403);
  await call('leader','post',path).send({username:`${pid}_missing`}).expect(404);
  assert.equal((await inbox('outsider').get()).size,0);
  const results=await Promise.all([call('leader','post',path).send({username}),call('leader','post',path).send({username})]);
  assert.deepEqual(results.map(r=>r.status).sort(),[201,409]);
  const rows=await inbox('outsider').get();
  assert.equal(rows.size,1);
  assert.equal(rows.docs[0].data().type,'member_added');
  assert.equal(rows.docs[0].data().read,false);
  assert.equal(rows.docs[0].data().body,'Bạn đã được thêm vào “QA dự án thông báo”.');
  assert.equal((await project.collection('members').doc(users.outsider.uid).get()).exists,true);
  assert.equal((await db.doc(`users/${users.outsider.uid}/projectMemberships/${pid}`).get()).exists,true);
  assert.equal((await inbox('member').get()).size,memberCount);
  assert.equal((await inbox('leader').get()).size,leaderCount);
  assert.equal(sends.length,sent+1);
  assert.deepEqual(sends.at(-1).tokens,[newToken]);
  assert.equal(sends.at(-1).data.type,'member_added');
  await call('leader','post',path).send({username}).expect(409);
  assert.equal((await inbox('outsider').get()).size,1);
  assert.equal(sends.length,sent+1);
});

test('joining by code also saves a single project notification even when push is unavailable',async () => {
  await call('leader','delete',`/projects/${pid}/members/${users.outsider.uid}`).expect(200);
  failPush=true;
  await call('outsider','post','/projects/join').send({joinCode:pid}).expect(201);
  failPush=false;
  const rows=await inbox('outsider').get();
  assert.equal(rows.size,2);
  assert.equal(rows.docs.filter(d=>d.data().type==='project_joined').length,1);
  await call('outsider','post','/projects/join').send({joinCode:pid}).expect(409);
  assert.equal((await inbox('outsider').get()).size,2);
});

test('every current member, including newly joined members, receives documents, votes and meetings once',async () => {
  const baseline=Object.fromEntries(await Promise.all(Object.keys(users).map(async role=>[role,(await inbox(role).get()).size])));
  const sent=sends.length;
  const payloads=[
    ['documents',{label:'Tài liệu nhóm mới',url:'https://example.com/doc'},'document'],
    ['votes',{question:'Chọn đề tài',options:['A','B']},'vote'],
    ['meetings',{label:'Họp nhóm',startsAt:new Date(Date.now()+86400000).toISOString(),endsAt:new Date(Date.now()+90000000).toISOString()},'meeting'],
  ];
  const expectedIds=[];
  for(const [collection,payload,type] of payloads){
    const response=await call('leader','post',`/projects/${pid}/workspace/${collection}`).send(payload).expect(201);
    expectedIds.push([response.body.id,type]);
  }
  for(const role of ['member','outsider']){
    const rows=await inbox(role).get();
    assert.equal(rows.size,baseline[role]+3);
    for(const [id,type] of expectedIds){
      const messages=rows.docs.filter(d=>d.data().targetId===id);
      assert.equal(messages.length,1);
      assert.equal(messages[0].data().type,type);
      assert.equal(messages[0].data().projectId,pid);
      assert.equal(messages[0].data().read,false);
    }
  }
  assert.equal((await inbox('leader').get()).size,baseline.leader);
  assert.equal((await inbox('unrelated').get()).size,baseline.unrelated);
  assert.equal(sends.length,sent+3);
  assert.deepEqual(sends.slice(sent).map(m=>m.data.type),['document','vote','meeting']);
  await call('unrelated','post',`/projects/${pid}/workspace/documents`).send({label:'Unauthorized'}).expect(403);
  await call('leader','post',`/projects/${pid}/workspace/documents`).send({label:'Invalid',url:'javascript:alert(1)'}).expect(400);
  assert.equal(sends.length,sent+3);
  await call('leader','delete',`/projects/${pid}/members/${users.outsider.uid}`).expect(200);
  await call('leader','post',`/projects/${pid}/workspace/documents`).send({label:'Sau khi rời nhóm'}).expect(201);
  assert.equal((await inbox('outsider').get()).size,baseline.outsider+3);
  assert.equal((await inbox('member').get()).size,baseline.member+4);
});
