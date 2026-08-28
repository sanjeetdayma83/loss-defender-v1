export default () => ({
  nodeEnv: process.env.NODE_ENV || "development",
  port: parseInt(process.env.PORT || "3000", 10),
  apiVersion: process.env.API_VERSION || "v1",
  database: { url: process.env.DATABASE_URL },
  redis: { url: process.env.REDIS_URL || "redis://localhost:6379" },
  clerk: {
    secretKey: process.env.CLERK_SECRET_KEY,
    publishableKey: process.env.CLERK_PUBLISHABLE_KEY,
    authorizedParties: (process.env.CLERK_AUTHORIZED_PARTIES || "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean),
    webhookSigningSecret: process.env.CLERK_WEBHOOK_SIGNING_SECRET,
  },
  b2: {
    keyId: process.env.B2_KEY_ID,
    applicationKey: process.env.B2_APPLICATION_KEY,
    bucket: process.env.B2_BUCKET,
    endpoint: process.env.B2_ENDPOINT,
    signedUrlTtl: parseInt(process.env.B2_SIGNED_URL_TTL || "900", 10),
  },
  razorpay: {
    keyId: process.env.RAZORPAY_KEY_ID,
    keySecret: process.env.RAZORPAY_KEY_SECRET,
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || "60000", 10),
    max: parseInt(process.env.RATE_LIMIT_MAX || "100", 10),
  },
});
