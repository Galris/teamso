// Các hàm đọc JSON linh hoạt (backend có thể đặt tên trường khác nhau).

Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return null;
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return [];
  return value.map(asMap).whereType<Map<String, dynamic>>().toList();
}

dynamic firstValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) return json[key];
  }
  return null;
}

String stringValue(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  final value = firstValue(json, keys);
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// Lấy danh sách từ response dạng `{projects: [...]}`, `{data: [...]}`
/// hoặc `{data: {projects: [...]}}`.
List<Map<String, dynamic>> extractList(
  Map<String, dynamic> response,
  List<String> keys,
) {
  for (final key in keys) {
    if (response[key] is List) return asMapList(response[key]);
  }
  final data = response['data'];
  if (data is List) return asMapList(data);
  final nested = asMap(data);
  if (nested != null) {
    for (final key in keys) {
      if (nested[key] is List) return asMapList(nested[key]);
    }
  }
  return [];
}

String normalizeStatus(String value) {
  switch (value.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim()) {
    case 'todo':
    case 'to do':
    case 'pending':
    case 'cần làm':
      return 'Cần làm';
    case 'in progress':
    case 'doing':
    case 'đang làm':
      return 'Đang làm';
    case 'submitted':
    case 'waiting review':
    case 'pending review':
    case 'chờ duyệt':
      return 'Chờ duyệt';
    case 'revision':
    case 'needs changes':
    case 'cần sửa':
      return 'Cần sửa';
    case 'done':
    case 'completed':
    case 'hoàn thành':
      return 'Hoàn thành';
    default:
      return value.isEmpty ? 'Cần làm' : value;
  }
}
