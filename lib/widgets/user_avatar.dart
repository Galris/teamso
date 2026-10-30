import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.large = false, this.url = ''});
  final bool large;
  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.person_rounded,
      size: large ? 65 : 40,
      color: AppColors.darkPurple,
    );
    return CircleAvatar(
      radius: large ? 45 : 30,
      backgroundColor: AppColors.softPurple,
      child: ClipOval(
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                width: large ? 90 : 60,
                height: large ? 90 : 60,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
