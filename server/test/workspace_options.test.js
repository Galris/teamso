import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import request from 'supertest';
import {registerWorkspace} from '../src/workspace.js';

function fixture() {
  const rows = new Map([
    ['projects/p', {ownerId:'leader',memberIds:['member']}],
    ['projects/p/votes/v', {options:['A','B']}],
    ['projects/p/votes/v/ballots/member', {options:[1]}],
  ]);
  const ref = path => ({path, doc: id => ref(`${path}/${id}`), collection: name => ref(`${path}/${name}`)});
  let tail = Promise.resolve();
  const db = {collection: name => ref(name), runTransaction: fn => {
    const run=tail.then(()=>fn({get:async r=>({exists:rows.has(r.path),data:()=>rows.get(r.path)}),update:(r,value)=>rows.set(r.path,{...rows.get(r.path),...value})}));
    tail=run.catch(()=>{}); return run;
  }};
  const app=express();app.use(express.json());
  registerWorkspace(app,{db,protectedRoute:(req,res,next)=>{req.uid=req.get('X-User');if(!req.uid)return res.sendStatus(401);next();}});
  app.use((err,req,res,next)=>res.status(err.status||500).json({message:err.message}));
  return {rows,add:(uid,option)=>request(app).post('/api/projects/p/workspace/votes/v/options').set('X-User',uid).send({option})};
}

test('append permits members, keeps option indices and existing ballots',async()=>{
  const {rows,add}=fixture();
  await add('member',' C ').expect(201);
  assert.deepEqual(rows.get('projects/p/votes/v').options,['A','B','C']);
  assert.deepEqual(rows.get('projects/p/votes/v/ballots/member').options,[1]);
  await add('leader','D').expect(201);
  await add('outsider','E').expect(403);
});
test('append rejects duplicate, blank, overlong, full and deleted polls',async()=>{
  const {rows,add}=fixture();
  for(const value of [' a ','','x'.repeat(121)])await add('member',value).expect(400);
  rows.set('projects/p/votes/v',{options:Array.from({length:20},(_,i)=>String(i))});
  await add('member','extra').expect(400);
  rows.set('projects/p/votes/v',{options:['A','B'],deleting:true});
  await add('member','C').expect(404);
  rows.delete('projects/p/votes/v');
  await add('member','C').expect(404);
});
test('simultaneous append requests both survive transaction serialization',async()=>{
  const {rows,add}=fixture();
  await Promise.all([add('member','C').expect(201),add('member','D').expect(201)]);
  assert.deepEqual(rows.get('projects/p/votes/v').options,['A','B','C','D']);
});
