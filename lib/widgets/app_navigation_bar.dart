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
    'Không gian nhóm',
    'Workspace',
    Icons.folder_outlined,
    Icons.folder_rounded,
  ),
  AppDestination(
    'Trò chuyện',
    'Chat',
    Icons.chat_bubble_outline_rounded,
    Icons.chat_bubble_rounded,
  ),
  AppDestination(
    'Thông báo',
    'Thông báo',
    Icons.notifications_none_rounded,
    Icons.notifications_rounded,
  ),
];

Widget appDestinationIcon(
  int index, {
  required bool selected,
  ValueListenable<int>? unread,
}) {
  final destination = appDestinations[index];
  final icon = Icon(selected ? destination.selectedIcon : destination.icon);
  if (index != 4 || unread == null) return icon;
  return ValueListenableBuilder<int>(
    valueListenable: unread,
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
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueListenable<int>? unread;
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
            icon: appDestinationIcon(i, selected: false, unread: unread),
            selectedIcon: appDestinationIcon(i, selected: true, unread: unread),
            label: appDestinations[i].label,
          ),
      ],
    ),
  );
}
