import 'package:flutter/material.dart';

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
    final path = company.logoUrl?.trim();
    final url = path == null || path.isEmpty
        ? null
        : path.startsWith('http://') || path.startsWith('https://')
            ? path
            : '${ApiConfig.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
    final headers = token?.isNotEmpty == true
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    Widget fallback() => Icon(Icons.factory_outlined, color: SteelColors.primary, size: size * .48);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .12),
      decoration: BoxDecoration(
        color: Colors.white,
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
