import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class AppDestination {
  const AppDestination(this.title, this.label, this.icon, this.selectedIcon);
  final String title, label;
  final IconData icon, selectedIcon;
}

const appDestinations = [
  AppDestination(
    'TeamUp',
    'Trang chủ',
    Icons.home_outlined,
    Icons.home_rounded,
  ),
  AppDestination(
    'Bảng công việc',
    'Công việc',
    Icons.checklist_rounded,
    Icons.checklist_rtl_rounded,
  ),
  AppDestination(
    'Workspace',
    'Workspace',
    Icons.layers_outlined,
    Icons.layers_outlined,
  ),
  AppDestination(
    'Chat',
    'Chat',
    Icons.chat_bubble_outline_rounded,
    Icons.chat_bubble_outline_rounded,
  ),
  AppDestination(
    'Thông báo',
    'Thông báo',
    Icons.notifications_none_rounded,
    Icons.notifications_none_rounded,
  ),
];

/// Màu nhấn riêng cho từng tab để thanh điều hướng bớt đơn điệu.
const _tabAccents = [
  AppColors.purple,
  AppColors.green,
  Color(0xFFE1B32C),
  AppColors.pink,
  AppColors.darkPurple,
];

Color appDestinationAccent(int index) =>
    _tabAccents[index % _tabAccents.length];

Widget appDestinationIcon(
  int index, {
  required bool selected,
  ValueListenable<int>? unread,
  ValueListenable<int>? chatUnread,
}) {
  final destination = appDestinations[index];
  final icon = AnimatedScale(
    scale: selected ? 1.12 : 1.0,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutBack,
    child: Icon(
      destination.icon,
      color: selected ? Colors.white : AppColors.textSecondary,
    ),
  );
  final counter = index == 3
      ? chatUnread
      : index == 4
      ? unread
      : null;
  if (counter == null) return icon;
  return ValueListenableBuilder<int>(
    valueListenable: counter,
    builder: (_, count, _) => Badge(
      isLabelVisible: count > 0,
      label: Text(count > 9 ? '9+' : '$count'),
      backgroundColor: AppColors.pink,
      child: icon,
    ),
  );
}

/// Shared by the main shell and Profile; switching tabs never creates another shell.
class AppNavigationBar extends StatelessWidget {
  const AppNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unread,
    this.chatUnread,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueListenable<int>? unread;
  final ValueListenable<int>? chatUnread;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: NavigationBar(
      selectedIndex: selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: onSelected,
      destinations: [
        for (var i = 0; i < appDestinations.length; i++)
          NavigationDestination(
            icon: appDestinationIcon(
              i,
              selected: false,
              unread: unread,
              chatUnread: chatUnread,
            ),
            selectedIcon: appDestinationIcon(
              i,
              selected: true,
              unread: unread,
              chatUnread: chatUnread,
            ),
            label: appDestinations[i].label,
          ),
      ],
    ),
  );
}
