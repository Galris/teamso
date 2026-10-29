import 'package:flutter/material.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  // Dữ liệu mẫu, chưa kết nối cơ sở dữ liệu.
  final List<String> _documents = [
    'Google Drive - Tài liệu dự án',
    'Google Docs - Biên bản họp nhóm',
    'Google Sheets - Phân công công việc',
  ];

  final List<String> _meetings = ['Họp nhóm - Thứ Sáu, 19:00'];

  final List<String> _voteOptions = [
    'Thứ Sáu - 19:00',
    'Thứ Bảy - 14:00',
    'Chủ Nhật - 09:00',
  ];

  final List<int> _voteCounts = [0, 0, 0];

  String _voteQuestion = 'Nhóm nên họp vào thời gian nào?';
  int? _selectedVote;

  Future<String?> _showInputDialog({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                final text = value.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(dialogContext, text);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    Navigator.pop(dialogContext, value);
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addDocument() async {
    final value = await _showInputDialog(
      title: 'Thêm tài liệu',
      label: 'Tên tài liệu hoặc đường dẫn',
    );

    if (!mounted || value == null) return;

    setState(() {
      _documents.add(value);
    });
  }

  Future<void> _addMeeting() async {
    final value = await _showInputDialog(
      title: 'Thêm lịch họp',
      label: 'Tên cuộc họp và thời gian',
    );

    if (!mounted || value == null) return;

    setState(() {
      _meetings.add(value);
    });
  }

  Future<void> _createVote() async {
    final question = await _showInputDialog(
      title: 'Tạo bình chọn',
      label: 'Nội dung câu hỏi',
    );

    if (!mounted || question == null) return;

    setState(() {
      _voteQuestion = question;
      _selectedVote = null;

      for (var i = 0; i < _voteCounts.length; i++) {
        _voteCounts[i] = 0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã tạo câu hỏi mẫu. Các phương án hiện được giữ nguyên.',
        ),
      ),
    );
  }

  void _submitVote(int index) {
    if (_selectedVote != null) return;

    setState(() {
      _selectedVote = index;
      _voteCounts[index]++;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã ghi nhận bình chọn mẫu.')));
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    VoidCallback? onAdd,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    tooltip: 'Thêm mới',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDocuments() {
    if (_documents.isEmpty) {
      return const Text('Chưa có tài liệu nào.');
    }

    return Column(
      children: [
        for (var i = 0; i < _documents.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(_documents[i]),
            subtitle: const Text('Tài liệu mẫu'),
            trailing: IconButton(
              tooltip: 'Xóa tài liệu',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  _documents.removeAt(i);
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVote() {
    final totalVotes = _voteCounts.fold<int>(0, (sum, count) => sum + count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _voteQuestion,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        RadioGroup<int>(
          groupValue: _selectedVote,
          onChanged: (value) {
            if (value != null && _selectedVote == null) {
              _submitVote(value);
            }
          },
          child: Column(
            children: [
              for (var i = 0; i < _voteOptions.length; i++)
                RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_voteOptions[i]),
                  subtitle: Text('${_voteCounts[i]} phiếu'),
                  value: i,
                  enabled: _selectedVote == null,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Tổng số phiếu: $totalVotes'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _createVote,
          icon: const Icon(Icons.add_chart),
          label: const Text('Tạo bình chọn mới'),
        ),
      ],
    );
  }

  Widget _buildMeetings() {
    if (_meetings.isEmpty) {
      return const Text('Chưa có lịch họp nào.');
    }

    return Column(
      children: [
        for (var i = 0; i < _meetings.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(_meetings[i]),
            subtitle: const Text('Lịch họp mẫu'),
            trailing: IconButton(
              tooltip: 'Xóa lịch họp',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  _meetings.removeAt(i);
                });
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'TeamUp Workspace',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Không gian tổng hợp tài liệu, bình chọn '
          'và lịch họp của nhóm.',
        ),
        const SizedBox(height: 20),

        _buildSection(
          title: 'Tài liệu nhóm',
          icon: Icons.folder_outlined,
          onAdd: _addDocument,
          child: _buildDocuments(),
        ),

        _buildSection(
          title: 'Quick Vote',
          icon: Icons.how_to_vote_outlined,
          child: _buildVote(),
        ),

        _buildSection(
          title: 'Lịch họp nhóm',
          icon: Icons.groups_outlined,
          onAdd: _addMeeting,
          child: _buildMeetings(),
        ),
      ],
    );
  }
}
