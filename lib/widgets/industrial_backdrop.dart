import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../core/app_theme.dart';

/// Mesma fotografia do desktop; a camada escura mantém o texto legível.
class IndustrialBackdrop extends StatelessWidget {
  const IndustrialBackdrop({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login-industry.webp',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            alignment: Alignment.center,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xC7000000),
                  Color(0x8F000000),
                  Color(0xB8000000),
                ],
                stops: [0, .5, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 24 : 40),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final small = compact || constraints.maxHeight < 360;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      strings.get('connectedIndustry').toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SteelColors.industrialAccentLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: Text(
                        strings.get('desktopHero'),
                        maxLines: small ? 3 : 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: small ? 23 : 36,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                          letterSpacing: -.5,
                        ),
                      ),
                    ),
                    if (!small) ...[
                      const SizedBox(height: 20),
                      Flexible(
                        child: Text(
                          strings.get('desktopHeroCaption'),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
