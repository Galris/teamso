import 'package:flutter/material.dart';

/// Hộp thoại nhập văn bản dùng chung.
///
/// Controller được tạo và hủy bên trong `State` của dialog, nên chỉ bị hủy khi
/// animation đóng đã kết thúc. Cách cũ (`await showDialog` rồi `controller
/// .dispose()` ngay) làm TextField vẫn đang chạy animation đóng nhưng controller
/// đã bị hủy -> lỗi "TextEditingController was used after being disposed" và
/// hiện màn hình đỏ.
///
/// Trả về văn bản đã trim; null nếu người dùng bấm Hủy hoặc bấm ra ngoài.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String? message,
  String? hint,
  String initialText = '',
  String confirmLabel = 'Đồng ý',
  int minLines = 1,
  int maxLines = 1,
  bool showField = true,
  String? Function(String text)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      label: label,
      message: message,
      hint: hint,
      initialText: initialText,
      confirmLabel: confirmLabel,
      minLines: minLines,
      maxLines: maxLines,
      showField: showField,
      validator: validator,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.message,
    required this.hint,
    required this.initialText,
    required this.confirmLabel,
    required this.minLines,
    required this.maxLines,
    required this.showField,
    required this.validator,
  });

  final String title;
  final String label;
  final String? message;
  final String? hint;
  final String initialText;
  final String confirmLabel;
  final int minLines;
  final int maxLines;
  final bool showField;
  final String? Function(String text)? validator;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.showField && !(_form.currentState?.validate() ?? true)) return;
    Navigator.of(context).pop(
      widget.showField ? _controller.text.trim() : widget.initialText.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.message != null) Text(widget.message!),
              if (widget.message != null && widget.showField)
                const SizedBox(height: 12),
              if (widget.showField)
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hint,
                  ),
                  validator: (value) =>
                      widget.validator?.call((value ?? '').trim()),
                  onFieldSubmitted: widget.maxLines == 1
                      ? (_) => _submit()
                      : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
