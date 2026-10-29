import { mkdirSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
mkdirSync('postman', { recursive: true });
const script = (listen, source) => ({ listen, script: { type: 'text/javascript', exec: source.trim().split('\n') } });
const expectStatus = code => `pm.test('HTTP ${code}', function () { pm.response.to.have.status(${code}); });`;
const tokenTests = `
if (pm.response.code === 200) {
  const data = pm.response.json();
  pm.test('Response has both tokens', function () {
    pm.expect(data.accessToken).to.be.a('string').and.not.empty;
    pm.expect(data.refreshToken).to.be.a('string').and.not.empty;
  });
  pm.environment.set('accessToken', data.accessToken);
  pm.environment.set('refreshToken', data.refreshToken);
}`;
function request(name, method, path, { body, protectedRoute = false, token = 'accessToken', expected = 200, pre = '', tests = '', description = '' } = {}) {
  const item = { name, request: { method, header: body ? [{ key: 'Content-Type', value: 'application/json' }] : [], url: '{{baseUrl}}' + path, description, auth: protectedRoute ? { type: 'bearer', bearer: [{ key: 'token', value: `{{${token}}}`, type: 'string' }] } : { type: 'noauth' } }, event: [script('test', expectStatus(expected) + '\n' + tests)] };
  if (body) item.request.body = { mode: 'raw', raw: JSON.stringify(body, null, 2), options: { raw: { language: 'json' } } };
  if (pre) item.event.unshift(script('prerequest', pre));
  return item;
}
const items = [
  request('00 - Health (Firebase)', 'GET', '/health', { tests: "pm.test('Backend uses Firestore', function () { pm.expect(pm.response.json().database).to.eql('Cloud Firestore'); });" }),
  request('01 - Signup / Dang ky', 'POST', '/auth/signup', { expected: 201,
    description: 'Creates a NEW local test account on every Send. Uses no personal email or existing account.',
    pre: `const suffix = Date.now().toString();
pm.environment.set('username', 'nghi_pm_' + suffix);
pm.environment.set('email', 'nghi_pm_' + suffix + '@example.com');
pm.environment.set('password', pm.environment.get('initialPassword') || 'TeamUp-test-123');
pm.environment.unset('accessToken');
pm.environment.unset('refreshToken');
pm.environment.unset('previousAccessToken');`,
    body: { username: '{{username}}', email: '{{email}}', password: '{{password}}', displayName: '{{displayName}}', major: 'Flutter Developer', phone: '0912345678' } }),
  request('02 - Signin / Dang nhap', 'POST', '/auth/signin', { body: { username: '{{username}}', password: '{{password}}' }, tests: tokenTests }),
  request('03 - Me / Xem ho so', 'GET', '/users/me', { protectedRoute: true, tests: `pm.test('Correct account and no password hash', function () {
  const user = pm.response.json().user;
  pm.expect(user.username).to.eql(pm.environment.get('username'));
  pm.expect(user).not.to.have.property('hashPassword');
});` }),
  request('04 - Profile / Luu ho so', 'PUT', '/users/profile', { protectedRoute: true,
    body: { displayName: '{{displayName}} - Updated', major: 'Flutter & Firebase', phone: '0912345678', bio: 'Kiem thu API TeamUp bang Postman.', avatarUrl: '' },
    tests: "pm.test('Profile saved', function () { pm.expect(pm.response.json().user.major).to.eql('Flutter & Firebase'); });" }),
  request('05 - Refresh / Cap lai token', 'POST', '/auth/refresh', { body: { refreshToken: '{{refreshToken}}' }, tests: tokenTests }),
  request('06 - Change password / Doi mat khau', 'PUT', '/users/change-password', { protectedRoute: true,
    description: 'Changes ONLY the generated test account password. Run request 07 to log in again.',
    body: { currentPassword: '{{password}}', newPassword: '{{newPassword}}' },
    tests: `if (pm.response.code === 200) {
  pm.environment.set('password', pm.environment.get('newPassword'));
  pm.environment.unset('accessToken'); pm.environment.unset('refreshToken');
}` }),
  request('07 - Signin with new password', 'POST', '/auth/signin', { body: { username: '{{username}}', password: '{{password}}' }, tests: tokenTests }),
  request('08 - Signout / Dang xuat', 'POST', '/auth/signout', { body: { refreshToken: '{{refreshToken}}' },
    // Firebase revocation timestamps have one-second precision.
    pre: 'setTimeout(function () {}, 1200);',
    tests: `if (pm.response.code === 200) {
  pm.environment.set('previousAccessToken', pm.environment.get('accessToken'));
  pm.environment.unset('accessToken'); pm.environment.unset('refreshToken');
}` }),
  request('09 - Old token rejected (expected 401)', 'GET', '/users/me', { protectedRoute: true, token: 'previousAccessToken', expected: 401 }),
  request('10 - Invalid refresh rejected (expected 401)', 'POST', '/auth/refresh', { body: { refreshToken: 'invalid-test-token' }, expected: 401 }),
];
const collection = { info: { _postman_id: randomUUID(), name: 'TeamUp - Firebase Auth & Profile (Local)', schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json', description: 'Run in order 00 -> 10. Select TeamUp Local environment. Signup creates a new synthetic account each run. No real tokens are included in this file.' }, item: items };
const values = { baseUrl: 'http://127.0.0.1:3000/api', username: '', email: '', displayName: 'Nghi Postman', initialPassword: 'TeamUp-test-123', password: '', newPassword: 'TeamUp-new-456', accessToken: '', refreshToken: '', previousAccessToken: '' };
const environment = { id: randomUUID(), name: 'TeamUp Local', values: Object.entries(values).map(([key, value]) => ({ key, value, type: /Token|Password|^password$/.test(key) ? 'secret' : 'default', enabled: true })), _postman_variable_scope: 'environment', _postman_exported_using: 'TeamUp local generator' };
writeFileSync('postman/TeamUp.postman_collection.json', JSON.stringify(collection, null, 2) + '\n');
writeFileSync('postman/TeamUp.local.postman_environment.json', JSON.stringify(environment, null, 2) + '\n');
console.log('Created 11 requests and an environment template with no real tokens.');
