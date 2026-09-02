class Env {
  static const apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:3000/api/v1",
  );

  /// Clerk Dashboard → API Keys → Publishable key (public, OK in client)
  /// Override: --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_...
  static const clerkPublishableKey = String.fromEnvironment(
    "CLERK_PUBLISHABLE_KEY",
    defaultValue: "pk_test_REPLACE_ME",
  );

  static bool get hasClerkKey =>
      clerkPublishableKey.isNotEmpty &&
      clerkPublishableKey.startsWith("pk_") &&
      !clerkPublishableKey.contains("REPLACE");
}