import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Hiện SnackBar nhất quán; luôn dọn snackbar cũ trước để không bị chồng.
void showAppSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline,
              color: error ? const Color(0xFFFFB4B4) : AppColors.green,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Trạng thái rỗng / lỗi dùng chung, có nút hành động tuỳ chọn.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.purpleSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (trailing != null)
        Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// Khối xương (skeleton) nhấp nháy khi đang tải – không cần package ngoài.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height, radius;
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFFEFEDF4),
          const Color(0xFFE2DFEB),
          _c.value,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Danh sách skeleton dạng thẻ cho lúc tải dữ liệu.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 92});
  final int count;
  final double itemHeight;
  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => SkeletonBox(height: itemHeight, radius: 14),
  );
}
