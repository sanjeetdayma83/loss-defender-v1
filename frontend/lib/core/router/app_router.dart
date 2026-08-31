import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../auth/session_provider.dart";
import "../../presentation/auth/login_screen.dart";
import "../../presentation/auth/splash_screen.dart";
import "../../presentation/dashboard/dashboard_screen.dart";
import "../../presentation/orders/orders_screen.dart";
import "../../presentation/orders/order_detail_screen.dart";
import "../../presentation/scanner/scanner_screen.dart";
import "../../presentation/recording/recording_screen.dart";
import "../../presentation/claims/claims_screen.dart";
import "../../presentation/returns/returns_screen.dart";
import "../../presentation/analytics/analytics_screen.dart";
import "../../presentation/evidence/evidence_screen.dart";
import "../../presentation/admin/admin_screen.dart";
import "../../presentation/settings/settings_screen.dart";

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: "/splash",
    refreshListenable: _SessionListenable(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final signedIn = session.isSignedIn;
      if (loc == "/splash") return null;
      if (!signedIn && loc != "/login") return "/login";
      if (signedIn && loc == "/login") return "/dashboard";
      return null;
    },
    routes: [
      GoRoute(path: "/splash", builder: (_, __) => const SplashScreen()),
      GoRoute(path: "/login", builder: (_, __) => const LoginScreen()),
      GoRoute(path: "/dashboard", builder: (_, __) => const DashboardScreen()),
      GoRoute(path: "/orders", builder: (_, __) => const OrdersScreen()),
      GoRoute(
        path: "/orders/:id",
        builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters["id"]!),
      ),
      GoRoute(
        path: "/scanner/:orderId",
        builder: (_, s) => ScannerScreen(orderId: s.pathParameters["orderId"]!),
      ),
      GoRoute(
        path: "/recording/:orderId",
        builder: (_, s) => RecordingScreen(orderId: s.pathParameters["orderId"]!),
      ),
      GoRoute(path: "/claims", builder: (_, __) => const ClaimsScreen()),
      GoRoute(path: "/returns", builder: (_, __) => const ReturnsScreen()),
      GoRoute(path: "/analytics", builder: (_, __) => const AnalyticsScreen()),
      GoRoute(
        path: "/evidence/:id",
        builder: (_, s) => EvidenceScreen(evidenceId: s.pathParameters["id"]!),
      ),
      GoRoute(path: "/admin", builder: (_, __) => const AdminScreen()),
      GoRoute(path: "/settings", builder: (_, __) => const SettingsScreen()),
    ],
  );
});

class _SessionListenable extends ChangeNotifier {
  _SessionListenable(this.ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}