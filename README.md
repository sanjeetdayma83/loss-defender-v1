# LOSS DEFENDER V1

Video Management System for e-commerce warehouse packing evidence.

**Stack:** NestJS + Prisma + Neon + Clerk + Backblaze B2 + Flutter (single codebase)

## Quick start (Windows PowerShell)

```powershell
cd "S:\LOSS DEFENDER V1\backend"
copy .env.example .env
# Edit .env — set real DATABASE_URL (Neon), CLERK_SECRET_KEY, B2_*
npx prisma generate
npx prisma migrate deploy   # or: npx prisma migrate dev
npm run start:dev
```

Health check (PowerShell-correct):

```powershell
Invoke-RestMethod http://localhost:3000/api/v1/health
Invoke-RestMethod http://localhost:3000/api/v1/billing/plans
```

Protected without token → expect **401**:

```powershell
try { Invoke-RestMethod http://localhost:3000/api/v1/companies/me } catch { $_.Exception.Response.StatusCode.value__ }
```

## Flutter

```powershell
cd "S:\LOSS DEFENDER V1\frontend"
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

## Structure

```
LOSS DEFENDER V1/
├── backend/          # NestJS API (ONLY source of backend truth)
├── frontend/         # Flutter (Android/iOS/Web/Windows)
├── docs/             # Blueprint + ADRs
└── scripts/          # PowerShell helpers
```

**Never put Nest source at repo root.** All API code lives under `backend/src/`.

## Security rules (non-negotiable)

1. `companyId` always from Clerk-linked User session — never from client body/query/path
2. Scanner is real validation — never a hardcoded "verified"
3. Webhooks verify signature on **raw body**
4. Guards fail closed
5. No passwords stored — Clerk owns identity

See `docs/LOSS_DEFENDER_V1_Complete_Project_Blueprint.md` for full spec.
