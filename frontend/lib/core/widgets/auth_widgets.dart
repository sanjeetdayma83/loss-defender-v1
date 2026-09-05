import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class AppLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AppLogo({super.key, this.size = 40, this.light = false});

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield_rounded, color: color, size: size),
        const SizedBox(width: 8),
        Text(
          "LOSS DEFENDER",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.45,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Desktop: split (brand panel + form). Mobile: centered card.
class AuthScaffold extends StatelessWidget {
  final Widget form;
  final String? sideTitle;
  final String? sideSubtitle;
  final List<String> sideBullets;
  final bool darkSide;

  const AuthScaffold({
    super.key,
    required this.form,
    this.sideTitle,
    this.sideSubtitle,
    this.sideBullets = const [],
    this.darkSide = true,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: form,
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              color: darkSide ? AppColors.navy : AppColors.primaryDark,
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(light: true, size: 36),
                  const Spacer(),
                  if (sideTitle != null)
                    Text(sideTitle!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        )),
                  if (sideSubtitle != null) ...[
                    const SizedBox(height: 12),
                    Text(sideSubtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 15,
                          height: 1.4,
                        )),
                  ],
                  if (sideBullets.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    ...sideBullets.map(
                      (b) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(b,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  )),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              color: AppColors.bg,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: form,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  final Widget child;
  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}