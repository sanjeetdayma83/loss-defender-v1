/** PM2 — run from backend/:  pm2 start ecosystem.config.cjs */
module.exports = {
  apps: [
    {
      name: "loss-defender-v1-api",
      script: "dist/main.js",
      instances: 1,
      exec_mode: "fork",
      env: {
        NODE_ENV: "production",
      },
      max_memory_restart: "512M",
      time: true,
    },
  ],
};
