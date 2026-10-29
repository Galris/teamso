import { z } from 'zod';

const username = z.string().trim().toLowerCase().regex(/^[a-z0-9_]{3,30}$/, 'Tên đăng nhập cần 3–30 ký tự: a-z, 0-9, _.');
const password = z.string().min(8, 'Mật khẩu cần ít nhất 8 ký tự.').refine(v => Buffer.byteLength(v, 'utf8') <= 72, 'Mật khẩu tối đa 72 byte UTF-8.');
const displayName = z.string().trim().min(1, 'Vui lòng nhập họ tên.').max(80);
const major = z.string().trim().max(120);
const phone = z.string().trim().max(30).refine(v => v === '' || /^[+\d\s()-]+$/.test(v) && v.replace(/\D/g, '').length >= 9 && v.replace(/\D/g, '').length <= 15, 'Số điện thoại cần 9–15 chữ số.');
export const signupSchema = z.object({ username, email: z.string().trim().toLowerCase().pipe(z.email()), password, displayName, major: major.optional(), phone: phone.optional() }).strict();
export const signinSchema = z.object({ username, password }).strict();
export const refreshSchema = z.object({ refreshToken: z.string().min(1).max(8192) }).strict();
export const profileSchema = z.object({ displayName: displayName.optional(), major: major.optional(), phone: phone.optional(), bio: z.string().trim().max(500).optional(), avatarUrl: z.union([z.literal(''), z.url().refine(v => new URL(v).protocol === 'https:', 'Ảnh đại diện cần URL HTTPS.')]).optional() }).strict().refine(v => Object.keys(v).length > 0, 'Không có thông tin cần cập nhật.');
export const changePasswordSchema = z.object({ currentPassword: z.string().min(1).max(256), newPassword: password }).strict().refine(v => v.currentPassword !== v.newPassword, 'Mật khẩu mới phải khác mật khẩu cũ.');
export function validate(schema, req) {
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) {
    const error = new Error(parsed.error.issues[0]?.message ?? 'Dữ liệu không hợp lệ.');
    error.status = 400;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }
  return parsed.data;
}
