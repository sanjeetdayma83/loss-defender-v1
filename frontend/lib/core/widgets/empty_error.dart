import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: AppColors.primary.withValues(alpha: 0.35)),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 24),
              if (primaryLabel != null)
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
              if (secondaryLabel != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String code; // 404, 500, offline, denied, session, maintenance, generic
  final VoidCallback? onRetry;
  final VoidCallback? onHome;

  const AppErrorState({
    super.key,
    required this.code,
    this.onRetry,
    this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final map = {
      "404": (Icons.travel_explore, "404", "Page Not Found",
          "The page you are looking for doesn't exist or has been moved."),
      "500": (Icons.cloud_off, "500", "Internal Server Error",
          "Something went wrong on our servers. Please try again later."),
      "offline": (Icons.wifi_off, "", "You're Offline",
          "Please check your internet connection and try again."),
      "denied": (Icons.lock_outline, "", "Access Denied",
          "You don't have permission to access this page."),
      "session": (Icons.timer_off, "", "Session Expired",
          "Your session has expired. Please log in again."),
      "maintenance": (Icons.build_circle_outlined, "", "We'll be back soon!",
          "The system is under maintenance."),
      "generic": (Icons.smart_toy_outlined, "", "Something Went Wrong",
          "An unexpected error occurred. Please try again."),
    };
    final t = map[code] ?? map["generic"]!;
    return EmptyState(
      icon: t.$1,
      title: t.$2.isEmpty ? t.$3 : "${t.$2}\n${t.$3}",
      message: t.$4,
      primaryLabel: onRetry != null ? "Try Again" : null,
      onPrimary: onRetry,
      secondaryLabel: onHome != null ? "Go to Dashboard" : null,
      onSecondary: onHome,
    );
  }
}