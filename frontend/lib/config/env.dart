class Env {
  static const apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://localhost:3000/api/v1",
  );

  static const clerkPublishableKey = String.fromEnvironment(
    "CLERK_PUBLISHABLE_KEY",
    defaultValue: "",
  );

  static bool get hasClerkKey => clerkPublishableKey.trim().isNotEmpty;
}