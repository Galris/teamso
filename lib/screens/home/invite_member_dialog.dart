import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
import '../../services/team_services.dart';

/// Hộp thoại thêm thành viên: gõ email hoặc username, tài khoản khớp hiện ra
/// ngay khi gõ, chọn một người rồi bấm thêm. Trả về hồ sơ đã chọn, null nếu hủy.
Future<Map<String, dynamic>?> showInviteMemberDialog(
  BuildContext context, {
  required ProjectService service,
  required Set<String> existingUids,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        _InviteMemberDialog(service: service, existingUids: existingUids),
  );
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({
    required this.service,
    required this.existingUids,
  });

  final ProjectService service;
  final Set<String> existingUids;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  static const _debounce = Duration(milliseconds: 350);

  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;

  /// Lượt tìm gần nhất; kết quả của lượt cũ bị bỏ vì đã có yêu cầu mới hơn.
  int _requestId = 0;
  bool _searching = false;
  bool _searchedOnce = false;
  String? _searchError;
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleSearch);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_scheduleSearch);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _runSearch);
  }

  Future<void> _runSearch() async {
    final term = _controller.text.trim();
    final request = ++_requestId;

    if (term.length < 2) {
      setState(() {
        _searching = false;
        _searchedOnce = false;
        _searchError = null;
        _results = const [];
        _selected = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final rows = await widget.service.searchAccounts(term);
      if (!mounted || request != _requestId) return;
      setState(() {
        _searching = false;
        _searchedOnce = true;
        _results = rows;
        _selected = null;
      });
    } catch (error) {
      if (!mounted || request != _requestId) return;
      setState(() {
        _searching = false;
        _searchedOnce = true;
        _results = const [];
        _searchError = errorText(error);
      });
    }
  }

  String _displayNameOf(Map<String, dynamic> row) =>
      (row['displayName'] ?? row['username'] ?? 'Tài khoản').toString();

  String _initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  Widget _candidateTile(Map<String, dynamic> row) {
    final uid = row['uid']?.toString() ?? '';
    final isMember = widget.existingUids.contains(uid);
    final name = _displayNameOf(row);
    final username = (row['username'] ?? '').toString();
    final email = (row['email'] ?? '').toString();
    final avatarUrl = (row['avatarUrl'] ?? '').toString();
    final isSelected = _selected?['uid']?.toString() == uid;

    return ListTile(
      enabled: !isMember,
      selected: isSelected,
      onTap: isMember ? null : () => setState(() => _selected = row),
      leading: avatarUrl.isNotEmpty
          ? CircleAvatar(
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: AppColors.purpleSoft,
            )
          : CircleAvatar(
              backgroundColor: AppColors.purpleSoft,
              child: Text(
                _initialsOf(name),
                style: const TextStyle(
                  color: AppColors.darkPurple,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [if (username.isNotEmpty) '@$username', if (email.isNotEmpty) email]
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isMember
          ? const SizedBox(
              width: 92,
              child: Text(
                'Đã là thành viên',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            )
          : Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: isSelected ? AppColors.green : AppColors.darkPurple,
            ),
    );
  }

  Widget _buildBody() {
    if (_searchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          _searchError!,
          style: const TextStyle(color: AppColors.danger),
        ),
      );
    }

    if (_searching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    if (_controller.text.trim().length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Nhập ít nhất 2 ký tự của email hoặc tên đăng nhập để tìm tài khoản.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (_searchedOnce && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Không tìm thấy tài khoản nào khớp. Kiểm tra lại email hoặc username.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final row in _results) _candidateTile(row)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _selected;

    return AlertDialog(
      title: const Text('Thêm thành viên'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Email hoặc username',
                prefixIcon: Icon(Icons.person_search_rounded),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(child: _buildBody()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: candidate == null
              ? null
              : () => Navigator.pop(context, candidate),
          child: Text(
            candidate == null
                ? 'Thêm vào dự án'
                : 'Thêm ${_displayNameOf(candidate)}',
          ),
        ),
      ],
    );
  }
}
