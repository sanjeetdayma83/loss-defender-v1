class Env {
  static const apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://127.0.0.1:3000/api/v1",
  );
  static const clerkPublishableKey = String.fromEnvironment(
    "CLERK_PUBLISHABLE_KEY",
    defaultValue: "",
  );
}