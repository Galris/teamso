import {test} from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import request from 'supertest';
import {FieldValue} from 'firebase-admin/firestore';
import {registerDirectChats,directChatId} from '../src/direct_chats.js';
function fixture(){
 const rows=new Map([['usernames/alice',{uid:'a'}],['usernames/bobby',{uid:'b'}],['usernames/carol',{uid:'c'}],...['a','b','c'].map(uid=>[`users/${uid}`,{displayName:uid,username:uid}])]);let serial=0,clock=1000,tail=Promise.resolve(),txTime=null;
 const stamp=()=>{const ms=++clock;return {toMillis:()=>ms,toDate:()=>new Date(ms)};};
 const resolve=v=>{if(v?.isEqual?.(FieldValue.serverTimestamp()))return txTime||stamp();if(Array.isArray(v))return v.map(resolve);if(v&&typeof v==='object'&&!v.toMillis)return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,resolve(x)]));return v;};
 const snap=ref=>({id:ref.path.split('/').at(-1),ref,exists:rows.has(ref.path),data:()=>rows.get(ref.path)});
 const ref=path=>({path,id:path.split('/').at(-1),collection:name=>col(`${path}/${name}`),get:async()=>snap(ref(path))});
 const col=(path,filters=[],order=null,count=Infinity,before=null)=>({path,doc:id=>ref(`${path}/${id||`m${++serial}`}`),where:(f,op,v)=>col(path,[...filters,[f,op,v]],order,count,before),orderBy:(f,dir)=>col(path,filters,[f,dir],count,before),limit:n=>col(path,filters,order,n,before),startAfter:s=>col(path,filters,order,count,s.id),get:async()=>{
  let docs=[...rows.keys()].filter(k=>k.startsWith(path+'/')&&k.split('/').length===path.split('/').length+1).map(k=>snap(ref(k))).filter(d=>filters.every(([f,op,v])=>op==='array-contains'?d.data()[f]?.includes(v):d.data()[f]===v));
  if(order)docs.sort((a,b)=>{const av=a.data()[order[0]]?.toMillis?.()||0,bv=b.data()[order[0]]?.toMillis?.()||0;return order[1]==='desc'?bv-av:av-bv;});if(before)docs=docs.slice(docs.findIndex(d=>d.id===before)+1);docs=docs.slice(0,count);return {docs,size:docs.length};
 }});
 const update=(r,v)=>{const data={...rows.get(r.path)};for(const [k,x]of Object.entries(v)){if(k.startsWith('names.'))data.names={...data.names,[k.slice(6)]:resolve(x)};else data[k]=resolve(x);}rows.set(r.path,data);};
 const tx={get:r=>r.get(),create:(r,v)=>{assert.ok(!rows.has(r.path));rows.set(r.path,resolve(v));},update};
 const db={collection:col,runTransaction:fn=>{const job=tail.then(async()=>{txTime=stamp();try{return await fn(tx);}finally{txTime=null;}});tail=job.catch(()=>{});return job;},batch:()=>({update,commit:async()=>{}})};
 const notices=[];const app=express();app.use(express.json());registerDirectChats(app,{db,protectedRoute:(req,res,next)=>{req.uid=req.get('X-User');if(!req.uid)return res.sendStatus(401);req.user={displayName:req.uid};next();},messageLimit:(req,res,next)=>next(),notifications:{stage:(writer,uids,data)=>uids.map(uid=>{const r=col(`users/${uid}/notifications`).doc();writer.create(r,{...data,createdAt:FieldValue.serverTimestamp(),read:false});notices.push({uid,...data});return{uid};}),deliver:async()=>{}}});app.use((err,req,res,next)=>res.status(err.status||500).json({message:err.message}));
 const call=(uid,method,path)=>request(app)[method](`/api/direct-chats${path}`).set('X-User',uid);
 return {app,rows,call,notices,stamp};
}
test('direct chat: validates username, no self-chat, idempotent pair and third-party isolation',async()=>{
 const {app,rows,call}=fixture();await request(app).post('/api/direct-chats').send({username:'bobby'}).expect(401);
 for(const username of ['', 'bad/name','alice'])await call('a','post','').send({username}).expect(400);
 await call('a','post','').send({username:'missing'}).expect(404);
 const [one,two]=await Promise.all([call('a','post','').send({username:'BOBBY'}).expect(201),call('b','post','').send({username:'alice'}).expect(201)]);
 assert.equal(one.body.id,two.body.id);assert.equal(one.body.id,directChatId('a','b'));assert.equal([...rows.keys()].filter(x=>/^directChats\/[^/]+$/.test(x)).length,1);
 assert.equal((await call('a','get','').expect(200)).body.rooms.length,1);assert.equal((await call('c','get','').expect(200)).body.rooms.length,0);
 await call('c','get',`/${one.body.id}/messages`).expect(403);await call('c','post',`/${one.body.id}/messages`).send({content:'no'}).expect(403);await call('c','post',`/${one.body.id}/read`).send({messageId:'no'}).expect(403);
});
test('direct messages preserve authoritative sender, notify recipient, and read only through cutoff',async()=>{
 const {rows,call,notices,stamp}=fixture();const id=(await call('a','post','').send({username:'bobby'})).body.id;
 for(const content of ['', 'x'.repeat(2001)])await call('a','post',`/${id}/messages`).send({content}).expect(400);
 const first=(await call('a','post',`/${id}/messages`).send({content:' Hello ',senderId:'forged'}).expect(201)).body.id;
 const second=(await call('a','post',`/${id}/messages`).send({content:'Second'}).expect(201)).body.id;
 assert.deepEqual(notices.map(n=>n.uid),['b','b']);assert.equal(notices[0].conversationId,id);
 const messages=(await call('b','get',`/${id}/messages`).expect(200)).body.messages;assert.equal(messages[0].senderId,'a');assert.equal(messages[0].content,'Hello');assert.ok(messages[0].createdAt);
 const preview=(await call('b','get','').expect(200)).body.rooms[0].lastMessage;assert.equal(preview.id,second);assert.ok(preview.createdAt);
 rows.set('users/b/notifications/unrelated',{type:'chat',conversationId:'other',createdAt:stamp(),read:false});
 await call('b','post',`/${id}/read`).send({messageId:first}).expect(200);
 const inbox=[...rows.entries()].filter(([key])=>key.startsWith('users/b/notifications/')).map(([,value])=>value);
 assert.equal(inbox.find(n=>n.targetId===first).chatRead,true);assert.equal(inbox.find(n=>n.targetId===first).read,false);assert.notEqual(inbox.find(n=>n.targetId===second).chatRead,true);assert.notEqual(inbox.find(n=>n.conversationId==='other').chatRead,true);
 await call('a','get','/invalid/messages').expect(400);await call('b','post',`/${id}/read`).send({messageId:'missing'}).expect(404);
});
test('direct history supports paging older than the latest hundred messages',async()=>{
 const {rows,call,stamp}=fixture();const id=(await call('a','post','').send({username:'bobby'})).body.id;
 for(let i=0;i<105;i++)rows.set(`directChats/${id}/messages/history${i}`,{content:String(i),senderId:'a',createdAt:stamp()});
 const page=(await call('b','get',`/${id}/messages`).expect(200)).body;assert.equal(page.messages.length,100);assert.equal(page.hasMore,true);assert.equal(page.messages[0].content,'5');
 const older=(await call('b','get',`/${id}/messages?before=${page.messages[0].id}`).expect(200)).body;assert.equal(older.messages.length,5);assert.equal(older.messages[0].content,'0');assert.equal(older.hasMore,false);
});
