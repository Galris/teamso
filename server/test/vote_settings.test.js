import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import request from 'supertest';
import { registerWorkspace } from '../src/workspace.js';

const inFuture = new Date(Date.now() + 86400000).toISOString();
const inPast = new Date(Date.now() - 86400000).toISOString();

function fixture(seed = []) {
  const rows = new Map([['projects/p', { ownerId: 'leader', memberIds: ['member', 'other'] }], ...seed]);
  let autoId = 0;
  const ref = path => {
    const id = path.split('/').pop();
    return { path, id, doc: next => ref(`${path}/${next ?? `auto${autoId++}`}`), collection: name => ref(`${path}/${name}`) };
  };
  const isDocument = path => path.split('/').length % 2 === 0;
  let tail = Promise.resolve();
  const db = {
    collection: name => ref(name),
    runTransaction: fn => {
      const run = tail.then(() => fn({
        get: async r => isDocument(r.path)
          ? { exists: rows.has(r.path), data: () => rows.get(r.path) }
          : { docs: [...rows.keys()].filter(k => k.startsWith(`${r.path}/`)).map(k => ({ ref: ref(k), data: () => rows.get(k) })) },
        create: (r, value) => rows.set(r.path, value),
        set: (r, value) => rows.set(r.path, value),
        update: (r, value) => rows.set(r.path, { ...rows.get(r.path), ...value }),
        delete: r => rows.delete(r.path),
      }));
      tail = run.catch(() => {});
      return run;
    },
  };
  const app = express();
  app.use(express.json());
  registerWorkspace(app, { db, protectedRoute: (req, res, next) => { req.uid = req.get('X-User'); if (!req.uid) return res.sendStatus(401); next(); } });
  app.use((err, req, res, next) => res.status(err.status || 500).json({ message: err.message }));
  const call = (uid, method, path) => request(app)[method](`/api/projects/p/workspace${path}`).set('X-User', uid);
  return { rows, call, vote: path => rows.get(`projects/p/votes/${path}`), ballot: uid => rows.get(`projects/p/votes/v/ballots/${uid}`) };
}

const voteRow = (data = {}) => ['projects/p/votes/v', { question: 'Q', kind: 'general', options: ['A', 'B', 'C'], createdBy: 'member', ...data }];

test('create vote stores multiple, anonymous and a Date deadline', async () => {
  const { call, vote } = fixture();
  const id = (await call('member', 'post', '/votes').send({ question: 'Chọn giờ', options: ['A', 'B'], multiple: true, anonymous: true, deadline: inFuture }).expect(201)).body.id;
  const saved = vote(id);
  assert.equal(saved.multiple, true);
  assert.equal(saved.anonymous, true);
  assert.equal(saved.deadline.toISOString(), new Date(inFuture).toISOString());
  assert.equal(saved.createdBy, 'member');
});

test('create vote defaults settings for old clients and meeting polls', async () => {
  const { call, vote } = fixture();
  const plain = (await call('member', 'post', '/votes').send({ question: 'Q', options: ['A', 'B'] }).expect(201)).body.id;
  assert.deepEqual({ multiple: vote(plain).multiple, anonymous: vote(plain).anonymous, deadline: vote(plain).deadline, kind: vote(plain).kind }, { multiple: false, anonymous: false, deadline: null, kind: 'general' });
  const slots = Array.from({ length: 60 }, (_, i) => `S${i}`);
  const meeting = (await call('member', 'post', '/votes').send({ question: 'Khung giờ', kind: 'meeting', options: slots }).expect(201)).body.id;
  assert.equal(vote(meeting).kind, 'meeting');
});

test('create vote still rejects unrecognized keys and bad deadlines', async () => {
  const { call } = fixture();
  await call('member', 'post', '/votes').send({ question: 'Q', options: ['A', 'B', 'C'], mutiple: true }).expect(400);
  await call('member', 'post', '/votes').send({ question: 'Q', options: ['A', 'B'], deadline: '05/11/2026' }).expect(400);
  await call('member', 'post', '/votes').send({ question: 'Q', options: ['A', 'B'], multiple: 'true' }).expect(400);
});

test('ballot is refused once the deadline passed', async () => {
  const { call, rows } = fixture([voteRow({ deadline: new Date(Date.now() - 1000) })]);
  const blocked = await call('member', 'put', '/votes/v/ballot').send({ options: [0] }).expect(400);
  assert.match(blocked.body.message, /hết hạn/);
  rows.set('projects/p/votes/v', voteRow({ deadline: new Date(Date.now() + 600000) })[1]);
  await call('member', 'put', '/votes/v/ballot').send({ options: [0] }).expect(200);
  rows.set('projects/p/votes/v', voteRow({ deadline: null })[1]);
  await call('member', 'put', '/votes/v/ballot').send({ options: [1] }).expect(200);
  // Firestore trả Timestamp có toDate(), không phải Date.
  rows.set('projects/p/votes/v', voteRow({ deadline: { toDate: () => new Date(Date.now() - 1000) } })[1]);
  await call('member', 'put', '/votes/v/ballot').send({ options: [0] }).expect(400);
});

test('patch keeps ballots by indexMap, drops removed options and rejects non-editors', async () => {
  const { call, rows, vote, ballot } = fixture([
    voteRow(), ['projects/p/votes/v/ballots/member', { options: [0, 2] }], ['projects/p/votes/v/ballots/other', { options: [1] }],
  ]);
  await call('outsider', 'patch', '/votes/v').send({ question: 'Q2' }).expect(403);
  await call('other', 'patch', '/votes/v').send({ question: 'Q2' }).expect(403);
  await call('member', 'patch', '/votes/v').send({ question: 'Q mới', options: ['C', 'A', 'D'], indexMap: [2, 0, null] }).expect(200);
  assert.deepEqual(vote('v').options, ['C', 'A', 'D']);
  assert.equal(vote('v').question, 'Q mới');
  assert.deepEqual(ballot('member').options, [0, 1]);
  assert.equal(rows.has('projects/p/votes/v/ballots/other'), false);
  rows.set('projects/p/votes/v/ballots/other', { options: [2] });
  await call('leader', 'patch', '/votes/v').send({ deadline: inFuture }).expect(200);
  assert.equal(vote('v').deadline.toISOString(), new Date(inFuture).toISOString());
  assert.deepEqual(ballot('other').options, [2]);
  await call('leader', 'patch', '/votes/v').send({ deadline: null }).expect(200);
  assert.equal(vote('v').deadline, null);
});

test('patch converts a legacy single-option ballot when remapping', async () => {
  const { call, ballot } = fixture([voteRow(), ['projects/p/votes/v/ballots/member', { option: 2 }]]);
  await call('member', 'patch', '/votes/v').send({ options: ['X', 'Y', 'C'], indexMap: [1, 0, 2] }).expect(200);
  assert.deepEqual(ballot('member').options, [2]);
});

test('patch rejects empty bodies, unknown keys and invalid index maps', async () => {
  const { call, rows } = fixture([voteRow()]);
  await call('member', 'patch', '/votes/v').send({}).expect(400);
  await call('member', 'patch', '/votes/v').send({ anonymous: true }).expect(400);
  await call('member', 'patch', '/votes/v').send({ options: ['A', 'B'], indexMap: [0] }).expect(400);
  await call('member', 'patch', '/votes/v').send({ options: ['A', 'B'], indexMap: [0, 0] }).expect(400);
  await call('member', 'patch', '/votes/v').send({ options: ['A', 'B'], indexMap: [0, 3] }).expect(400);
  await call('member', 'patch', '/votes/v').send({ indexMap: [0, 1] }).expect(400);
  await call('member', 'patch', '/votes/v').send({ options: [' a ', 'A'] }).expect(400);
  await call('member', 'patch', '/votes/v').send({ options: Array.from({ length: 21 }, (_, i) => `S${i}`) }).expect(400);
  rows.set('projects/p/votes/v', voteRow({ deleting: true })[1]);
  await call('member', 'patch', '/votes/v').send({ question: 'Q' }).expect(404);
});

test('patch without indexMap keeps votes by position', async () => {
  const { call, ballot } = fixture([voteRow(), ['projects/p/votes/v/ballots/member', { options: [0, 2] }]]);
  await call('member', 'patch', '/votes/v').send({ options: ['A mới', 'B', 'C'] }).expect(200);
  assert.deepEqual(ballot('member').options, [0, 2]);
});
