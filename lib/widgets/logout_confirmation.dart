import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';

Future<bool> confirmLogout(BuildContext context) async {
  final strings = AppStrings.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: SteelColors.danger.withValues(alpha: .10), shape: BoxShape.circle),
            child: const Icon(Icons.logout_rounded, color: SteelColors.danger, size: 28),
          ),
          title: Text(strings.get('confirmLogoutTitle')),
          content: Text(strings.get('confirmLogoutMessage'), textAlign: TextAlign.center),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(strings.get('cancel'))),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: SteelColors.danger),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(strings.get('confirmLogoutAction')),
            ),
          ],
        ),
      ) ??
      false;
}
