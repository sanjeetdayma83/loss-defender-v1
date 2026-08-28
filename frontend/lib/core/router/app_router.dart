import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "../../presentation/auth/login_screen.dart";
import "../../presentation/dashboard/dashboard_screen.dart";
import "../../presentation/scanner/scanner_screen.dart";
import "../../presentation/orders/orders_screen.dart";

GoRouter createRouter({required bool isSignedIn}) {
  return GoRouter(
    initialLocation: isSignedIn ? "/dashboard" : "/login",
    routes: [
      GoRoute(path: "/login", builder: (_, __) => const LoginScreen()),
      GoRoute(path: "/dashboard", builder: (_, __) => const DashboardScreen()),
      GoRoute(path: "/orders", builder: (_, __) => const OrdersScreen()),
      GoRoute(path: "/scanner", builder: (_, __) => const ScannerScreen()),
    ],
  );
}