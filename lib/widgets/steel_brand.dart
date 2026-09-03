import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_theme.dart';
import '../core/app_strings.dart';

class SteelBrand extends StatelessWidget {
  const SteelBrand({this.compact = false, this.light = false, super.key});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final iconColor = light || dark ? Colors.white : SteelColors.ink;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
          decoration: BoxDecoration(
            color: light ? Colors.white.withValues(alpha: .12) : SteelColors.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(
              'assets/images/steel-icon.svg',
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SteelControl',
                style: TextStyle(
                  color: foreground,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              Text(
                AppStrings.of(context).get('industrialManagement'),
                style: TextStyle(
                  color: light ? Colors.white70 : SteelColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.25,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
