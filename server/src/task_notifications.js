// Keep recipient-specific review messages separate from ordinary task updates.
export function taskUpdateNotifications({ old, changes, project, projectId, taskId, actorId, actorName, members }) {
  const title = changes.title ?? old.title ?? 'Công việc';
  const status = changes.status ?? old.status;
  const common = { projectId, projectName: project.name || 'Dự án', targetId: taskId, taskTitle: title, status, actorName };
  const current = new Set(members.map(m => m.uid));
  current.add(project.ownerId);
  const assignees = [...new Set(changes.assigneeIds ?? old.assigneeIds ?? [])].filter(uid => current.has(uid));
  const added = assignees.filter(uid => !(old.assigneeIds ?? []).includes(uid));
  const jobs = added.map(uid => ({ uid, data: { ...common, type: 'assigned', title: 'Bạn được giao việc mới', body: `“${title}” vừa được giao cho bạn.` } }));
  const changed = Object.keys(changes).some(key => !['updatedAt', 'completedAt'].includes(key) && JSON.stringify(changes[key]) !== JSON.stringify(old[key]));
  if (!changed) return jobs;
  const transition = status !== old.status;
  if (transition && status === 'pending_review') {
    const reviewers = new Set([project.ownerId, ...members.filter(m => m.role === 'leader').map(m => m.uid)]);
    for (const uid of reviewers) {
      if (uid && uid !== actorId) jobs.push({ uid, data: { ...common, type: 'review_required', title: 'Cần bạn duyệt công việc', body: `${actorName} đã gửi “${title}” để bạn duyệt.`, outputLink: changes.outputLink ?? old.outputLink ?? '' } });
    }
    for (const uid of assignees) {
      if (reviewers.has(uid) && uid !== actorId) continue;
      jobs.push({ uid, data: { ...common, type: 'pending_review', title: 'Công việc đang chờ duyệt', body: `“${title}” đã được gửi và đang chờ trưởng nhóm duyệt.` } });
    }
    return jobs;
  }
  const recipients = new Set([...assignees, project.ownerId]);
  const labels = { todo: 'cần làm', in_progress: 'đang làm', completed: 'đã được duyệt hoàn thành', revision_required: 'cần sửa', pending_review: 'chờ duyệt' };
  for (const uid of recipients) {
    if (!uid || uid === actorId || added.includes(uid) || !current.has(uid)) continue;
    const reviewComment = changes.reviewComment ?? old.reviewComment ?? '';
    jobs.push({ uid, data: { ...common,
      type: transition && status === 'completed' ? 'completed' : transition && status === 'revision_required' ? 'revision_required' : 'updated',
      title: transition && status === 'completed' ? 'Công việc đã được duyệt' : transition && status === 'revision_required' ? 'Công việc cần sửa' : 'Công việc được cập nhật',
      body: transition ? `“${title}”: ${labels[status] ?? status}.${status === 'revision_required' && reviewComment ? ` Nhận xét: ${reviewComment}` : ''}` : `Thông tin “${title}” vừa thay đổi.`,
      ...(transition && ['completed', 'revision_required'].includes(status) ? { reviewComment } : {}),
    } });
  }
  return jobs;
}
