import {test} from 'node:test';
import assert from 'node:assert/strict';
import {taskUpdateNotifications} from '../src/task_notifications.js';

const base = {
  old: {title: 'Thiết kế đăng nhập', status: 'in_progress', assigneeIds: ['member', 'removed']},
  project: {name: 'Mobile App', ownerId: 'owner'}, projectId: 'project-a', taskId: 'task-a',
  actorId: 'member', actorName: 'Nghi',
  members: [{uid: 'owner', role: 'leader'}, {uid: 'reviewer', role: 'leader'}, {uid: 'member', role: 'member'}],
};
test('submission notifies each reviewer and confirms waiting to the submitter, with project/task context', () => {
  const rows = taskUpdateNotifications({...base, changes: {status: 'pending_review', outputLink: 'https://example.com/result'}});
  assert.deepEqual(rows.map(r => [r.uid, r.data.type]), [['owner', 'review_required'], ['reviewer', 'review_required'], ['member', 'pending_review']]);
  for (const {data} of rows) {
    assert.equal(data.projectName, 'Mobile App');
    assert.equal(data.taskTitle, 'Thiết kế đăng nhập');
    assert.equal(data.status, 'pending_review');
    assert.equal(data.actorName, 'Nghi');
  }
  assert.equal(rows[0].data.outputLink, 'https://example.com/result');
});
test('repeating a submission does not create duplicate waiting/review messages', () => {
  assert.deepEqual(taskUpdateNotifications({...base, old: {...base.old, status: 'pending_review'}, changes: {status: 'pending_review', updatedAt: {}}}), []);
});
test('revision sends the reason only to current assignees and excludes the reviewer actor', () => {
  const rows = taskUpdateNotifications({...base, actorId: 'owner', actorName: 'Trưởng nhóm', old: {...base.old, status: 'pending_review'}, changes: {status: 'revision_required', reviewComment: 'Bổ sung kiểm tra mật khẩu'}});
  assert.deepEqual(rows.map(r => r.uid), ['member']);
  assert.equal(rows[0].data.type, 'revision_required');
  assert.match(rows[0].data.body, /Bổ sung kiểm tra mật khẩu/);
});
test('approval notifies assignees and records the completed state', () => {
  const rows = taskUpdateNotifications({...base, actorId: 'owner', old: {...base.old, status: 'pending_review'}, changes: {status: 'completed'}});
  assert.deepEqual(rows.map(r => [r.uid, r.data.type]), [['member', 'completed']]);
});
test('ordinary changes still notify the owner and assignment does not duplicate updates', () => {
  assert.deepEqual(taskUpdateNotifications({...base, changes: {status: 'in_progress', title: 'Tên mới'}}).map(r => r.uid), ['owner']);
  const rows = taskUpdateNotifications({...base, actorId: 'owner', changes: {assigneeIds: ['member', 'reviewer'], title: 'Tên mới'}});
  assert.equal(rows.filter(r => r.uid === 'reviewer').length, 1);
  assert.equal(rows.find(r => r.uid === 'reviewer').data.type, 'assigned');
});
