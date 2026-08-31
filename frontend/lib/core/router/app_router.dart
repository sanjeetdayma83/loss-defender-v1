import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../auth/clerk_auth_holder.dart";
import "../providers/app_providers.dart";

import "../../presentation/auth/splash_screen.dart";
import "../../presentation/auth/auth_screen.dart";
import "../../presentation/auth/pending_invite_screen.dart";
import "../../presentation/dashboard/dashboard_screen.dart";
import "../../presentation/orders/orders_list_screen.dart";
import "../../presentation/orders/order_detail_screen.dart";
import "../../presentation/orders/order_create_screen.dart";
import "../../presentation/scanner/scanner_screen.dart";
import "../../presentation/recording/recording_screen.dart";
import "../../presentation/recording/dispatch_screen.dart";
import "../../presentation/evidence/evidence_viewer_screen.dart";
import "../../presentation/claims/claims_list_screen.dart";
import "../../presentation/claims/claim_detail_screen.dart";
import "../../presentation/returns/returns_list_screen.dart";
import "../../presentation/returns/return_detail_screen.dart";
import "../../presentation/admin/warehouses_screen.dart";
import "../../presentation/admin/users_screen.dart";
import "../../presentation/analytics/analytics_screen.dart";
import "../../presentation/settings/settings_screen.dart";
import "../../presentation/supervisor/supervisor_screen.dart";
import "../../presentation/offline/offline_queue_screen.dart";

GoRouter buildRouter(WidgetRef ref, Listenable refreshListenable) {
  return GoRouter(
    initialLocation: "/splash",
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final signedIn = ClerkAuthHolder.isSignedIn;
      final authRoute = loc == "/login" || loc == "/signup";

      if (!signedIn) {
        return authRoute ? null : "/login";
      }

      final profileAsync = ref.read(authSyncProvider);
      if (profileAsync.isLoading) {
        return loc == "/splash" ? null : "/splash";
      }

      final profile = profileAsync.valueOrNull;
      if (profile == null) {
        return loc == "/pending-invite" ? null : "/pending-invite";
      }

      if (authRoute || loc == "/splash" || loc == "/pending-invite") {
        return "/dashboard";
      }
      return null;
    },
    routes: [
      GoRoute(path: "/splash", builder: (_, __) => const SplashScreen()),
      GoRoute(path: "/login", builder: (_, __) => const AuthScreen()),
      GoRoute(path: "/signup", builder: (_, __) => const AuthScreen()),
      GoRoute(path: "/pending-invite", builder: (_, __) => const PendingInviteScreen()),
      GoRoute(path: "/dashboard", builder: (_, __) => const DashboardScreen()),

      GoRoute(path: "/orders", builder: (_, __) => const OrdersListScreen()),
      GoRoute(path: "/orders/new", builder: (_, __) => const OrderCreateScreen()),
      GoRoute(
        path: "/orders/:id",
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters["id"]!),
      ),

      GoRoute(
        path: "/scanner/:orderId",
        builder: (_, state) => ScannerScreen(orderId: state.pathParameters["orderId"]!),
      ),
      GoRoute(
        path: "/recording/:orderId",
        builder: (_, state) => RecordingScreen(orderId: state.pathParameters["orderId"]!),
      ),
      GoRoute(
        path: "/dispatch/:orderId",
        builder: (_, state) => DispatchScreen(orderId: state.pathParameters["orderId"]!),
      ),
      GoRoute(
        path: "/evidence/:id",
        builder: (_, state) => EvidenceViewerScreen(evidenceId: state.pathParameters["id"]!),
      ),

      GoRoute(path: "/claims", builder: (_, __) => const ClaimsListScreen()),
      GoRoute(
        path: "/claims/:id",
        builder: (_, state) => ClaimDetailScreen(claimId: state.pathParameters["id"]!),
      ),

      GoRoute(path: "/returns", builder: (_, __) => const ReturnsListScreen()),
      GoRoute(
        path: "/returns/:id",
        builder: (_, state) => ReturnDetailScreen(returnId: state.pathParameters["id"]!),
      ),

      GoRoute(path: "/admin/warehouses", builder: (_, __) => const WarehousesScreen()),
      GoRoute(path: "/admin/users", builder: (_, __) => const UsersScreen()),
      GoRoute(path: "/analytics", builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: "/settings", builder: (_, __) => const SettingsScreen()),
      GoRoute(path: "/supervisor", builder: (_, __) => const SupervisorScreen()),
      GoRoute(path: "/offline-queue", builder: (_, __) => const OfflineQueueScreen()),
    ],
  );
}