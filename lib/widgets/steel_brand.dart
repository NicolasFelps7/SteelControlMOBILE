import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';

class SteelBrand extends StatelessWidget {
  const SteelBrand({this.compact = false, this.light = false, super.key});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final secondary = light
        ? const Color(0xFFAEB8BD)
        : dark
            ? SteelColors.mutedDark
            : SteelColors.muted;
    final iconColor = light ? SteelColors.ink : (dark ? Colors.white : SteelColors.ink);
    final plate = light
        ? const Color(0xFFF4F5F5)
        : dark
            ? const Color(0xFF242D32)
            : Colors.white;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: plate,
            border: Border.all(
              color: light ? const Color(0xFF505B61) : (dark ? SteelColors.borderDark : SteelColors.border),
            ),
            borderRadius: BorderRadius.circular(9),
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
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SteelControl',
                style: TextStyle(
                  color: foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.25,
                ),
              ),
              Text(
                AppStrings.of(context).get('industrialManagement'),
                style: TextStyle(
                  color: secondary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .95,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
