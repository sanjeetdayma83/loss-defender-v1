# Deploy notes (ExCloud / any VPS)

## One-time on server
1. Install Node 20, git, nginx, certbot, redis (or use docker compose)
2. Clone repo, copy `backend/.env` with **production** Neon / Clerk / B2 keys
3. `cd backend && npm ci && npx prisma migrate deploy && npm run build`
4. `pm2 start ecosystem.config.cjs` OR `docker compose up -d --build` from repo root

## Nginx sketch
```
server {
  listen 443 ssl;
  server_name api.lossdefender.in;
  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

## Checklist before traffic
- [ ] HTTPS only
- [ ] Clerk production keys + authorized parties
- [ ] B2 private bucket
- [ ] Neon backups / branch
- [ ] `GET /api/v1/health` 200 from public URL
- [ ] One packing E2E on staging
