class Env {
  static const apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:3000/api/v1",
  );

  /// Clerk Dashboard → API Keys → Publishable key
  static const clerkPublishableKey = String.fromEnvironment(
    "CLERK_PUBLISHABLE_KEY",
    defaultValue: "",
  );

  static bool get hasClerkKey =>
      clerkPublishableKey.isNotEmpty && clerkPublishableKey.startsWith("pk_");
}