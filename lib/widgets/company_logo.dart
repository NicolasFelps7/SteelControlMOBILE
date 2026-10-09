import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../models/session.dart';

class CompanyLogo extends StatelessWidget {
  const CompanyLogo({required this.company, this.token, this.size = 56, super.key});

  final Company company;
  final String? token;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final path = company.logoUrl?.trim();
    final url = path == null || path.isEmpty
        ? null
        : path.startsWith('http://') || path.startsWith('https://')
            ? path
            : '${ApiConfig.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
    final headers = token?.isNotEmpty == true
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    Widget fallback() => Padding(
          padding: EdgeInsets.all(size * .08),
          child: SvgPicture.asset(
            'assets/images/steel-icon.svg',
            colorFilter: ColorFilter.mode(
              dark ? Colors.white : SteelColors.ink,
              BlendMode.srcIn,
            ),
          ),
        );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: BoxDecoration(
        color: url == null
            ? (dark ? SteelColors.ink : Colors.white)
            : Colors.white,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(size * .22),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback()
          : Image.network(url, headers: headers, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback()),
    );
  }
}
