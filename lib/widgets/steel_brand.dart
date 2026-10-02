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
    final iconColor = dark || light ? Colors.white : SteelColors.ink;
    final plate = dark || light ? SteelColors.ink : Colors.white;

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: plate,
            border: Border.all(
              color: dark || light ? SteelColors.borderDark : SteelColors.border,
            ),
            borderRadius: BorderRadius.circular(7),
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
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SteelControl',
                    maxLines: 1,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.25,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    AppStrings.of(context).get('industrialManagement'),
                    maxLines: 1,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .95,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
