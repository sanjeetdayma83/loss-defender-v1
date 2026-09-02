# LOSS DEFENDER V1 — Complete Project Blueprint

**Type:** Video Management System (VMS) for e-commerce warehouse packing evidence — **not** an e-commerce app itself.
**Status:** Build-from-scratch blueprint, ready to develop end-to-end
**Date:** 28 August 2026
**Classification:** Internal — Engineering Use Only

> This single document is the source of truth for building LOSS DEFENDER V1 from an empty folder to a deployed, production-ready system: what it is, how it's architected, every role/permission, every module, the full database schema, the API contract, the Flutter app spec, the exact PowerShell commands to create/build/run everything, the deployment steps, and the security rules that must never be broken. It bakes in lessons learned from auditing the earlier version of this product, so the mistakes found there don't get repeated here.

---

## Table of Contents

1. [Project Overview & Vision](#1-project-overview--vision)
2. [Confirmed Tech Stack & Services](#2-confirmed-tech-stack--services)
3. [Repository & Folder Structure](#3-repository--folder-structure)
4. [System Architecture](#4-system-architecture)
5. [Roles & Permissions (RBAC)](#5-roles--permissions-rbac)
6. [Core Modules & Features](#6-core-modules--features)
7. [Database Design (Full Prisma Schema)](#7-database-design-full-prisma-schema)
8. [Backend API Specification](#8-backend-api-specification)
9. [Flutter App Specification (Android / iOS / Web / Windows)](#9-flutter-app-specification)
10. [Development Workflow — 100% PowerShell/CMD](#10-development-workflow--100-powershellcmd)
11. [Deployment Guide — ExCloud VPS](#11-deployment-guide--excloud-vps)
12. [Security Model — Rules That Must Never Be Broken](#12-security-model--rules-that-must-never-be-broken)
13. [Testing Strategy](#13-testing-strategy)
14. [Go-Live Checklist](#14-go-live-checklist)
15. [Future Roadmap](#15-future-roadmap)

---

## 1. Project Overview & Vision

### 1.1 What LOSS DEFENDER V1 is

A **Video Management System (VMS)** built for e-commerce sellers and warehouse operators. When a seller packs an order for Amazon, Flipkart, Meesho, Shopify, WooCommerce, etc., LOSS DEFENDER:

1. Scans the order/AWB barcode
2. Records a timestamped, tamper-evident video of the entire packing process
3. Validates every item against the order via barcode scanning **during** packing (not after)
4. Uploads the video + frame evidence securely to private cloud storage
5. Lets the seller pull that evidence back up later to defend a false-return claim, missing-item claim, or courier-theft dispute

It is not a marketplace, not a storefront, not an inventory system — it is the **evidence layer** that sits between "order arrives" and "order leaves the warehouse."

### 1.2 Business problem → solution

| Problem | Impact | How this system solves it |
|---|---|---|
| Missing/wrong item shipped | Revenue loss, complaints | Barcode-verified packing with synchronized video |
| Courier theft / tampering | Empty/damaged package on arrival | Continuous video from scan to dispatch |
| Marketplace false claims & fake returns | Seller penalized, account health hit | Timestamped, operator-linked, immutable evidence |
| Operator mistakes | Wrong item/qty shipped | Real-time SKU validation during the scan, not after |
| No way to prove what was packed | Can't win disputes | Tamper-evident video + audit trail + chain of custody |

### 1.3 Product attributes (design constraints from day one)

| Attribute | What it means for the build |
|---|---|
| Multi-tenant SaaS | Every table carries `companyId`; every query is scoped to it server-side, never client-supplied |
| Offline-first | Flutter app must work with zero connectivity during scanning/recording; sync when back online |
| Mobile-first | Large touch targets, glove-friendly, minimal steps — operators aren't office workers |
| API-first | Backend is the single source of truth; Flutter (mobile/web/desktop) is the only client, all through one versioned REST API |
| Event-driven | Heavy work (video processing, notifications, marketplace sync) goes to background queues — the API never blocks on it |
| Secure by construction | Auth, tenant isolation, and RBAC are structural, not bolted on later |

### 1.4 Target customers

Small sellers (1–10 operators) up to marketplace fulfilment centres (1000+ operators), 3PLs managing multiple client warehouses, and manufacturers needing bulk-shipment proof.

### 1.5 Success KPIs

| Goal | KPI | Target |
|---|---|---|
| Reduce false claims | Claim win rate | >85% |
| Eliminate wrong dispatch | Packing accuracy | >99.5% |
| Full evidence coverage | % packed orders with evidence | 100% |
| Fast dispute resolution | Mean time to resolve | <5 minutes |

---

## 2. Confirmed Tech Stack & Services

These are locked in from day one — including local development. There is **no local Postgres, no local file storage** at any stage; you develop against the real cloud services from the very first commit, so there's never a "works locally, breaks in prod" surprise around DB/storage.

| Layer | Service | Console / URL | Used from |
|---|---|---|---|
| Database | Neon PostgreSQL | https://console.neon.tech/ | Day 1 (local dev too — use a separate Neon branch/project for dev vs prod) |
| Object storage | Backblaze B2 | https://www.backblaze.com/ | Day 1 (private bucket, signed URLs only) |
| Auth | Clerk | https://clerk.dev/ | Day 1 (see §12 — this replaces all password/OTP handling) |
| Payments | Razorpay | https://razorpay.com/ | From billing module onward |
| Compute (final deploy) | ExCloud VPS | https://console.excloud.dev/console/instance | After local dev + full testing |
| Domain/email | Hostinger | lossdefender.in | Deployment phase |
| CDN/WAF | Cloudflare | cloudflare.com | Deployment phase |

**Development stack:**

| Layer | Technology | Why |
|---|---|---|
| Frontend (all platforms) | **Flutter (Dart) only** — Android, iOS, Web, Windows from one codebase | You explicitly want one codebase for every surface, including the admin panel. Flutter Web serves the admin/manager/supervisor roles; the same app serves operators on Android. No separate React project. |
| Backend | NestJS + TypeScript | Modular, enterprise-grade, strong typing |
| ORM | Prisma | Type-safe queries + migrations against Neon |
| Auth verification | `@clerk/backend` | Verifies Clerk session tokens server-side |
| Cache/Queue | Redis + BullMQ | Sessions cache, rate limits, background jobs |
| Object storage SDK | `@aws-sdk/client-s3` + presigner (B2 is S3-compatible) | Signed upload/download URLs |
| Payments | `razorpay` npm package | Subscriptions, webhooks |
| Local DB on device | Drift (SQLite) | Offline queue for scans/recordings before upload |
| State management | Riverpod | Compile-time safe, scales well with role-based screens |
| Secure device storage | `flutter_secure_storage` | Clerk session token storage on device |
| Process manager | PM2 | Keeps the Node process alive in production |
| Reverse proxy | Nginx | SSL termination, routing |
| Containers | Docker + Docker Compose | Same image, local parity with prod |
| CI/CD | GitHub Actions | Lint → test → build → migrate → deploy |

---

## 3. Repository & Folder Structure

One repo, one root folder, exactly as you specified:

```
LOSS DEFENDER V1/
├── backend/                       # NestJS + TypeScript API
│   ├── src/
│   │   ├── auth/                  # Clerk verification guard + webhook + invite linking
│   │   ├── companies/             # Tenant management ("me"-scoped only, see §12)
│   │   ├── warehouses/            # Warehouse & station CRUD
│   │   ├── users/                 # User CRUD & invitation
│   │   ├── orders/                # Order lifecycle
│   │   ├── scanner/                # Barcode validation (REAL logic — see §12 lesson)
│   │   ├── recordings/            # Recording session control
│   │   ├── evidence/              # Frame extraction & proof generation
│   │   ├── upload/                # Multipart upload to B2
│   │   ├── claims/                # Claim management (built fully — see §12 lesson)
│   │   ├── returns/                # Return investigation
│   │   ├── marketplace/           # Marketplace sync & webhooks (raw-body HMAC — see §12)
│   │   ├── notifications/         # Email, push, WhatsApp
│   │   ├── analytics/             # KPIs & reports
│   │   ├── audit/                 # Audit log writes on every critical mutation
│   │   ├── billing/                # Razorpay integration
│   │   ├── common/
│   │   │   ├── guards/            # ClerkAuthGuard, TenantGuard, RolesGuard, PermissionsGuard, PlanLimitGuard
│   │   │   ├── interceptors/
│   │   │   ├── decorators/        # @Public(), @Roles(), @CurrentUser()
│   │   │   └── utils/             # tenantWhere() helper — used everywhere, no exceptions
│   │   ├── config/
│   │   └── prisma/
│   ├── prisma/
│   │   └── schema.prisma
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example
│   └── package.json
│
├── frontend/                       # Flutter — Android, iOS, Web, Windows (single codebase)
│   ├── lib/
│   │   ├── config/                 # Env, API base URL, Clerk publishable key
│   │   ├── core/                   # Theme, utils, extensions, error handling
│   │   ├── data/                   # API clients (Dio + Retrofit), repositories
│   │   ├── domain/                 # Models/entities, freezed classes
│   │   └── presentation/
│   │       ├── auth/                # Clerk sign-in/sign-up embedded flows
│   │       ├── dashboard/           # Role-aware home — routes by Clerk role claim
│   │       ├── scanner/
│   │       ├── recording/
│   │       ├── upload/
│   │       ├── orders/
│   │       ├── claims/
│   │       ├── returns/
│   │       ├── evidence/
│   │       ├── admin/              # Company/warehouse/user management (web/desktop-optimized, same app)
│   │       ├── analytics/
│   │       ├── settings/
│   │       └── supervisor/          # Live floor monitoring (desktop/web preferred layout)
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── windows/
│   └── pubspec.yaml
│
├── docs/                            # This document + future ADRs
├── scripts/                         # PowerShell automation (see §10)
├── .github/
│   └── workflows/                   # CI/CD pipelines
├── .gitignore
└── README.md
```

---

## 4. System Architecture

```
Flutter (Android/iOS/Web/Windows)
        │  HTTPS, Bearer <clerk_session_token>
        ▼
   Cloudflare (CDN/WAF)
        ▼
   Nginx (SSL termination)
        ▼
   NestJS API  ── /api/v1/...
        │
        ├──→ ClerkAuthGuard  (verifies token against Clerk)
        ├──→ TenantGuard     (derives companyId from token — never from client input)
        ├──→ RolesGuard      (checks @Roles(...) on the route)
        ├──→ PermissionsGuard(fine-grained permission matrix)
        ├──→ PlanLimitGuard  (enforces plan quotas)
        │
        ├──→ Prisma ──→ Neon PostgreSQL   (all state, every query companyId-scoped)
        ├──→ Redis  ──→ BullMQ workers    (video processing, notifications, marketplace sync)
        ├──→ Backblaze B2                 (private bucket, signed URLs only, 5–15 min TTL)
        ├──→ Clerk API                    (token verification, webhook events)
        └──→ Razorpay API                 (subscriptions, payment webhooks)
```

**Non-negotiable architecture rules** (violating any of these caused real bugs in the earlier version of this product — see §12 for the specific incidents):

1. Clients never talk to Neon or Redis directly — only through the NestJS API.
2. Clients never touch B2 directly except via short-lived signed URLs.
3. `companyId` is **derived from the authenticated user's Clerk-backed session**, never accepted from a request body, query string, or URL path. No controller anywhere reads `companyId` off `@Param()`/`@Query()`/`@Body()` and trusts it.
4. Every Prisma query that touches tenant data goes through one shared `tenantWhere()` helper — no ad-hoc `where: { companyId: ... }` scattered around with a chance of forgetting it.
5. All media is private. No public B2 buckets, ever.
6. Long-running work (video processing, AI jobs, marketplace sync, email) is always queued via BullMQ — the request/response cycle never waits on it.
7. API is versioned from commit #1: `/api/v1/...`.
8. Every webhook (Clerk, Razorpay, marketplace) verifies its signature against the **raw request body bytes**, never a re-serialized JSON object.

---

## 5. Roles & Permissions (RBAC)

### 5.1 Roles

| Role | Code | Primary surface |
|---|---|---|
| Super Admin | `super_admin` | Flutter (desktop/web layout) — platform-wide |
| Company Admin / Owner | `company_admin` | Flutter (all layouts) |
| Warehouse Manager | `warehouse_manager` | Flutter (all layouts) |
| Supervisor | `supervisor` | Flutter (desktop/web preferred — live floor view) |
| Packing Operator | `packing_operator` | Flutter (mobile — scan/record) |
| QC Operator | `qc_operator` | Flutter (mobile — review queue) |
| Claims Executive | `claims_executive` | Flutter (all layouts) |
| Marketplace Manager | `marketplace_manager` | Flutter (desktop/web) |
| Viewer | `viewer` | Flutter (read-only, all layouts) |
| Auditor | `auditor` | Flutter (desktop/web — audit logs only) |

Role is stored on your `User` row (source of truth), **not** trusted from Clerk's own metadata alone — Clerk only proves *who* someone is; your database says *what they can do* in *which company*. (This is the same design already proven solid in the earlier codebase's guard chain — reused here deliberately.)

### 5.2 Permission matrix

`✓*` = scoped to the caller's own assigned warehouse(s)/company only — enforced server-side by `TenantGuard`, never by the client.

| Permission | Super Admin | Company Admin | Manager | Supervisor | Operator | QC | Claims | Viewer |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| companies.read (own) | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| companies.read (all) | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| warehouses.crud | ✓ | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ |
| users.invite | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| orders.read | ✓ | ✓* | ✓* | ✓* | ✓* | ✗ | ✓* | ✓* |
| orders.create/assign | ✓ | ✓* | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ |
| scanner.use | ✓ | ✓* | ✓* | ✓* | ✓* | ✗ | ✗ | ✗ |
| recordings.create | ✓ | ✓* | ✓* | ✓* | ✓* | ✗ | ✗ | ✗ |
| recordings.review | ✓ | ✓* | ✓* | ✗ | ✗ | ✓* | ✗ | ✗ |
| evidence.read | ✓ | ✓* | ✓* | ✓* | ✓* | ✓* | ✓* | ✓* |
| evidence.download/share | ✓ | ✓* | ✓* | ✗ | ✗ | ✗ | ✓* | ✗ |
| claims.decide / returns.decide | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✓* | ✗ |
| marketplace.connect | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| analytics.read | ✓ | ✓* | ✓* | ✓* | ✗ | ✗ | ✓* | ✓* |
| audit.read | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| billing.manage | ✓ | ✓* | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

### 5.3 Role-based routing (Flutter)

After Clerk sign-in, the app calls `GET /auth/sync` once, gets back `{ companyId, role, warehouseId }`, and routes to a role-specific home:

| Role | Entry screen |
|---|---|
| `company_admin` | Admin Dashboard (KPIs, company overview) |
| `warehouse_manager` | Manager Dashboard (orders, assignments) |
| `supervisor` | Live Floor View |
| `packing_operator` | Operator Queue → Scan → Record |
| `qc_operator` | QC Review Queue |
| `claims_executive` | Claims Inbox |
| `viewer` | Read-only Dashboard |
| `super_admin` | Platform Admin (all companies) |

---

## 6. Core Modules & Features

| Module | Purpose | Priority | Target |
|---|---|---|---|
| Auth (Clerk) | Sign-up/in, session, invite-linking | Critical | v1.0 |
| Company | Tenant profile, plan, storage quota | Critical | v1.0 |
| Warehouse/Station | Locations, packing stations, device health | Critical | v1.0 |
| Users & RBAC | Invite, role assign, permission matrix | Critical | v1.0 |
| Orders | Lifecycle: synced → dispatched → closed/claimed/returned | Critical | v1.0 |
| Scanner | Real barcode/SKU/qty validation, duplicate-scan detection | Critical | v1.0 |
| Recording | Start/pause/stop, segmented capture, offline queue | Critical | v1.0 |
| Evidence | Frame extraction, overlays, checksums, signed retrieval | Critical | v1.0 |
| Upload | Resumable multipart to B2 | Critical | v1.0 |
| Dispatch | AWB capture, courier, status transition | Critical | v1.0 |
| Claims | Full lifecycle: create → evidence → decide → marketplace reply | High | v1.0 |
| Returns | Unboxing recording → inspect → decide | High | v1.0 |
| Marketplace | Amazon/Flipkart/Meesho/Shopify/WooCommerce sync + webhooks | High | v1.0 |
| Notifications | Email, push (FCM), WhatsApp | High | v1.0 |
| Audit | Every critical mutation logged, immutable | High | v1.0 |
| Analytics | KPI dashboards | High | v1.1 |
| Billing | Razorpay subscriptions, plan enforcement | Medium | v1.1 |
| AI verification | Object/SKU detection hooks | Future | v1.2+ |

### 6.1 Order lifecycle

```
synced → queued → packing → recording → scanned → evidence_ready → dispatched → shipped
                                                                          │
                                                     ┌────────────────────┼─────────────────────┐
                                                     ▼                    ▼                     ▼
                                                  closed            claimed→investigating     returned→received→inspected
                                                                    →closed                    →closed
```

### 6.2 Scanner flow (must be REAL logic — see §12)

```
Scan barcode → valid format? ──NO──→ red toast + haptic
     │YES
On this order? ──NO──→ red toast + haptic ("wrong SKU")
     │YES
Already scanned? ──YES──→ yellow toast ("duplicate")
     │NO
Green flash → increment scannedQty
     │
All items matched? ──NO──→ show remaining items
     │YES
Enable "Continue" → Recording screen
```

### 6.3 Billing plans (Razorpay)

| Plan | Users | Warehouses | Storage | Price (INR) |
|---|---|---|---|---|
| Free | 3 | 1 | 5 GB | ₹0 |
| Starter | 10 | 2 | 50 GB | ₹1,999/mo |
| Professional | 50 | 5 | 500 GB | ₹4,999/mo |
| Enterprise | Unlimited | Unlimited | 2 TB | Custom |

---

## 7. Database Design (Full Prisma Schema)

```prisma
// backend/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL") // Neon connection string, from day 1
}

enum Role {
  super_admin
  company_admin
  warehouse_manager
  supervisor
  packing_operator
  qc_operator
  claims_executive
  marketplace_manager
  viewer
  auditor
}

enum Plan { free starter professional enterprise }
enum Status { active suspended deleted }
enum UserStatus { pending active suspended deleted }
enum StationStatus { online offline maintenance inactive }
enum OrderStatus {
  synced queued packing recording scanned evidence_ready
  dispatched shipped claimed returned closed
}
enum RecordingStatus { started paused completed failed }
enum EvidenceStatus { processing ready failed }
enum ClaimStatus { open under_review investigating approved rejected escalated closed }
enum Marketplace { amazon flipkart meesho shopify woocommerce manual }

model Company {
  id                  String   @id @default(uuid())
  companyName         String
  email               String   @unique
  phone               String
  gst                 String?
  pan                 String?
  address             Json?
  timezone            String   @default("Asia/Kolkata")
  currency            String   @default("INR")
  plan                Plan     @default(free)
  storageUsed         BigInt   @default(0)
  storageQuota        BigInt   @default(5368709120) // 5GB
  status              Status   @default(active)
  logo                String?
  createdAt           DateTime @default(now())
  updatedAt           DateTime @updatedAt

  warehouses          Warehouse[]
  users               User[]
  orders              Order[]
  claims              Claim[]
  marketplaceAccounts MarketplaceAccount[]
  subscription        BillingSubscription?

  @@index([status])
}

// Clerk owns identity; this row owns tenant/role. No password field at all —
// this project never stores a password, from the very first commit.
model User {
  id               String     @id @default(uuid())
  clerkId          String?    @unique // null until the invite is accepted / first sign-in linked
  companyId        String
  employeeId       String?
  name             String
  email            String     @unique
  phone            String?
  role             Role       @default(packing_operator)
  warehouseId      String?
  stationId        String?
  status           UserStatus @default(pending)
  profilePhoto     String?
  joiningDate      DateTime?
  lastLoginAt      DateTime?
  createdAt        DateTime   @default(now())
  updatedAt        DateTime   @updatedAt

  company          Company    @relation(fields: [companyId], references: [id])
  warehouse        Warehouse? @relation(fields: [warehouseId], references: [id])

  @@index([companyId, status])
}

model InviteToken {
  id         String    @id @default(uuid())
  userId     String
  tokenHash  String    @unique
  expiresAt  DateTime
  usedAt     DateTime?
  createdAt  DateTime  @default(now())
}

model Warehouse {
  id         String   @id @default(uuid())
  companyId  String
  name       String
  code       String
  address    Json
  city       String
  state      String
  country    String   @default("India")
  timezone   String
  status     Status   @default(active)
  createdAt  DateTime @default(now())

  company    Company   @relation(fields: [companyId], references: [id])
  stations   Station[]
  orders     Order[]
  users      User[]

  @@unique([companyId, code])
  @@index([companyId, status])
}

model Station {
  id              String        @id @default(uuid())
  warehouseId     String
  stationName     String
  stationCode     String
  cameraConfig    Json?
  scannerConfig   Json?
  printerConfig   Json?
  status          StationStatus @default(offline)
  lastHeartbeatAt DateTime?

  warehouse       Warehouse @relation(fields: [warehouseId], references: [id])

  @@unique([warehouseId, stationCode])
}

model Order {
  id                 String      @id @default(uuid())
  companyId          String
  warehouseId        String?
  marketplace        Marketplace @default(manual)
  marketplaceOrderId String?
  status             OrderStatus @default(synced)
  items              Json        // [{sku, qty, name, scannedQty, status}]
  assignedOperatorId String?
  stationId          String?
  recordingId        String?     @unique
  evidenceId         String?     @unique
  awb                String?
  courier            String?
  dispatchedAt       DateTime?
  deliveredAt        DateTime?
  metadata           Json?
  createdAt          DateTime    @default(now())
  updatedAt          DateTime    @updatedAt

  company    Company    @relation(fields: [companyId], references: [id])
  warehouse  Warehouse? @relation(fields: [warehouseId], references: [id])
  recording  Recording? @relation(fields: [recordingId], references: [id])
  evidence   Evidence?  @relation(fields: [evidenceId], references: [id])
  claims     Claim[]

  @@index([companyId, status])
  @@index([marketplaceOrderId])
  @@index([companyId, createdAt])
}

model Recording {
  id           String          @id @default(uuid())
  companyId    String
  operatorId   String
  stationId    String?
  status       RecordingStatus @default(started)
  startedAt    DateTime        @default(now())
  stoppedAt    DateTime?
  segmentCount Int             @default(0)
  b2KeyPrefix  String?
  createdAt    DateTime        @default(now())

  order        Order?
  segments     RecordingSegment[]

  @@index([companyId])
}

model RecordingSegment {
  id           String    @id @default(uuid())
  recordingId  String
  sequence     Int
  b2Key        String
  checksum     String
  sizeBytes    BigInt
  uploadedAt   DateTime?

  recording    Recording @relation(fields: [recordingId], references: [id])

  @@unique([recordingId, sequence])
}

model Evidence {
  id          String         @id @default(uuid())
  companyId   String
  recordingId String         @unique
  status      EvidenceStatus @default(processing)
  frameCount  Int            @default(0)
  frames      Json?
  checksum    String?
  createdAt   DateTime       @default(now())

  order       Order?

  @@index([companyId])
}

model Claim {
  id          String         @id @default(uuid())
  companyId   String
  orderId     String
  reason      String
  marketplace Marketplace
  description String?
  status      ClaimStatus    @default(open)
  decision    String?
  decidedBy   String?
  decidedAt   DateTime?
  attachments Json?
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt

  company     Company        @relation(fields: [companyId], references: [id])
  order       Order          @relation(fields: [orderId], references: [id])

  @@index([companyId, status])
}

model Return {
  id                 String    @id @default(uuid())
  companyId          String
  orderId            String
  unboxingRecordingId String?
  condition          String?
  decision           String?
  decidedAt          DateTime?
  createdAt          DateTime  @default(now())
  updatedAt          DateTime  @updatedAt

  @@index([companyId])
}

model MarketplaceAccount {
  id             String      @id @default(uuid())
  companyId      String
  marketplace    Marketplace
  accessToken    String      // encrypted at the application layer before storage
  refreshToken   String?     // encrypted
  webhookSecret  String?     // encrypted
  status         Status      @default(active)
  lastSyncAt     DateTime?
  createdAt      DateTime    @default(now())

  company        Company     @relation(fields: [companyId], references: [id])

  @@unique([companyId, marketplace])
}

model Notification {
  id         String   @id @default(uuid())
  companyId  String
  userId     String?
  channel    String   // email | push | whatsapp | in_app
  payload    Json
  status     String   @default("pending")
  sentAt     DateTime?
  createdAt  DateTime @default(now())

  @@index([companyId, status])
}

// Written on every critical mutation — see §12. Never optional.
model AuditLog {
  id          String   @id @default(uuid())
  companyId   String
  actorId     String
  action      String
  entityType  String
  entityId    String
  beforeState Json?
  afterState  Json?
  ipAddress   String?
  userAgent   String?
  createdAt   DateTime @default(now())

  @@index([companyId, createdAt])
  @@index([actorId, action])
}

model Session {
  id         String    @id @default(uuid())
  userId     String
  clerkSessionId String @unique
  ipAddress  String?
  userAgent  String?
  createdAt  DateTime  @default(now())
  revokedAt  DateTime?

  @@index([userId])
}

model BillingSubscription {
  id                 String   @id @default(uuid())
  companyId          String   @unique
  razorpaySubId      String   @unique
  plan               Plan
  status             String   // active | paused | cancelled | past_due
  currentPeriodStart DateTime
  currentPeriodEnd   DateTime
  createdAt          DateTime @default(now())
  updatedAt          DateTime @updatedAt

  company            Company  @relation(fields: [companyId], references: [id])
}
```

**Design notes baked in from the start** (these are fixes applied *before* the bug ever happens, based on real issues found auditing the earlier version):

- `User.clerkId` is the identity link; there is **no password column anywhere in this schema.**
- Every tenant-scoped model carries `companyId` and has an index on `(companyId, ...)` — no table is scoped only by a bare `id` that a controller could leak across tenants.
- `AuditLog` exists from migration #1, not bolted on later.
- `MarketplaceAccount` tokens are described as "encrypted at the application layer" — encrypt/decrypt in the service layer using a key from your secret manager, never store plaintext OAuth tokens.

---

## 8. Backend API Specification

### 8.1 Base URL & versioning

```
Base URL (local):  http://localhost:3000/api/v1
Base URL (prod):   https://api.lossdefender.in/api/v1
Auth header:       Authorization: Bearer <clerk_session_token>
```

### 8.2 Response envelope

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": { "page": 1, "limit": 20, "total": 150, "requestId": "req-uuid" }
}
```

### 8.3 Auth endpoints (all Clerk-backed — see §12 for the full pattern)

| Method | Path | Purpose | Auth |
|---|---|---|---|
| POST | `/auth/accept-invite` | Link a Clerk identity to a pre-created invited User row | Public |
| GET | `/auth/sync` | Bootstrap client with `{companyId, role, warehouseId}` after sign-in | Bearer |
| POST | `/auth/logout` | Revoke local session record | Bearer |
| GET | `/auth/sessions` | List active sessions | Bearer |
| DELETE | `/auth/sessions/:id` | Revoke a session | Bearer |
| POST | `/webhooks/clerk` | Clerk lifecycle events (user.updated/deleted) | Public (Svix-signature verified) |

There is deliberately **no** `/auth/register`, `/auth/login`, `/auth/forgot-password`, `/auth/otp/*` — Clerk's SDK components on the Flutter client own 100% of sign-up/sign-in/password-reset/MFA.

### 8.4 Core resource endpoints

| Method | Path | Notes |
|---|---|---|
| GET / PATCH | `/companies/me` | Only ever "me"-scoped — no `/companies/:id` cross-tenant route exists |
| POST/GET/PATCH | `/warehouses`, `/warehouses/:id` | `companyId` always derived server-side |
| POST/GET/PATCH | `/users`, `/users/:id` | Invite, role assign |
| POST/GET/PATCH | `/orders`, `/orders/:id` | |
| POST | `/orders/:id/assign` | |
| POST | `/scanner/validate` | Real SKU/qty/duplicate validation — never a stub |
| POST | `/recordings/start`, `/recordings/stop` | |
| POST | `/upload/init`, `/upload/part`, `/upload/complete` | Resumable multipart to B2 |
| GET | `/evidence/:id` | Returns a signed URL, 5–15 min TTL |
| POST/GET/PATCH | `/claims`, `/claims/:id` | |
| POST/GET/PATCH | `/returns`, `/returns/:id` | |
| POST | `/marketplace/connect` | |
| POST | `/marketplace/webhooks/:provider` | Raw-body HMAC verified |
| GET | `/analytics/kpis` | |
| GET | `/audit-logs` | |
| POST | `/billing/subscribe` | Razorpay |
| POST | `/webhooks/razorpay` | Raw-body signature verified |

### 8.5 Guard chain (applied globally, in this order)

```
ClerkAuthGuard → TenantGuard → RolesGuard → PermissionsGuard → PlanLimitGuard
```

- **ClerkAuthGuard**: verifies the bearer token via `@clerk/backend`'s `verifyToken()`, looks up the linked `User` row by `clerkId`, populates `request.user = {id, companyId, role, warehouseId}`. Throws `403` if no linked User exists (no silent auto-provisioning of a bare Clerk sign-up into a tenant).
- **TenantGuard**: makes `request.user.companyId` the only source of truth for scoping; any `@Body()/@Query()/@Param()` field named `companyId` sent by the client is ignored/overwritten, never trusted.
- **RolesGuard** / **PermissionsGuard**: check `@Roles(...)` / `@RequirePermission(...)` metadata against the permission matrix in §5.2. Both **fail closed** — if role/permission can't be determined, throw `403`, never default to a real role.
- **PlanLimitGuard**: enforces the plan quotas in §6.3.

---

## 9. Flutter App Specification

### 9.1 One codebase, all platforms

```bash
flutter create --org com.lossdefender --project-name loss_defender_v1 .
```

Platform targets enabled: `android`, `ios`, `web`, `windows`. Role-aware layout: mobile-optimized (large touch targets, camera/scanner-first) for `packing_operator`/`qc_operator`; desktop/web-optimized (tables, multi-pane) for `company_admin`/`supervisor`/`marketplace_manager`/`auditor`. Riverpod + responsive breakpoints pick the right layout per screen at runtime — one codebase, two layout modes, not two apps.

### 9.2 Screen inventory

| Screen | Priority | Notes |
|---|---|---|
| Splash | P0 | Silent Clerk session check |
| Clerk sign-in/sign-up (embedded) | P0 | Clerk's Flutter components |
| Dashboard (role-aware) | P0 | Routes per §5.3 |
| Scanner | P0 | Camera or hardware keyboard-wedge scanner |
| Recording | P0 | Large REC button, barcode+timestamp overlay burned into video |
| Upload progress | P0 | Per-segment progress, auto-resume |
| Dispatch confirm | P0 | AWB + courier |
| Evidence viewer | P1 | Frame-by-frame |
| Claims / Returns list + detail | P1 | |
| Admin — company/warehouse/user management | P1 | Desktop/web layout |
| Analytics | P1 | |
| Settings / sessions | P1 | |
| Supervisor live view | P1 | Desktop/web layout preferred |
| Offline queue | P1 | Pending uploads |

### 9.3 Core operator flow

```
Dashboard → tap order → Order Detail (items + qty)
  → Scanner (live match vs expected, green/red flash)
  → Recording (REC, timer, segment count, pause/stop)
  → Upload Progress (auto-resumes if connection drops)
  → Dispatch Confirm (AWB, courier)
  → Success → back to Dashboard
```

### 9.4 Offline-first rule

Every scan and recording writes to the local Drift (SQLite) queue **first**, then syncs. A dropped connection during recording/upload never loses data — it shows an "will upload when online" banner and resumes the multipart upload automatically on reconnect.

### 9.5 Key pubspec dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.4.0
  dio: ^5.3.0
  retrofit: ^4.0.0
  drift: ^2.12.0
  drift_flutter: ^0.1.0
  sqlite3_flutter_libs: ^0.5.0
  flutter_secure_storage: ^9.0.0
  camera: ^0.10.5
  video_player: ^2.7.0
  mobile_scanner: ^3.4.0
  clerk_flutter: ^latest   # check pub.dev for the current Clerk Flutter SDK name/version
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0
  permission_handler: ^11.0.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  retrofit_generator: ^8.0.0
  drift_dev: ^2.12.0
  riverpod_generator: ^2.3.0
```

---

## 10. Development Workflow — 100% PowerShell/CMD

Every step below — folder creation, file edits, git operations, running/building — is done via PowerShell, as you specified.

### 10.1 One-time project setup

```powershell
# ============================================
# LOSS DEFENDER V1 — PROJECT INIT
# Run in PowerShell (as Administrator recommended)
# ============================================

$PROJECT_ROOT = "C:\Projects\LOSS DEFENDER V1"
New-Item -ItemType Directory -Path $PROJECT_ROOT -Force | Out-Null
Set-Location $PROJECT_ROOT

git init
git branch -M main
git remote add origin https://github.com/sanjeetdayma83/loss-defender-v1.git

$folders = @(
    "backend\src\auth","backend\src\companies","backend\src\warehouses","backend\src\users",
    "backend\src\orders","backend\src\scanner","backend\src\recordings","backend\src\evidence",
    "backend\src\upload","backend\src\claims","backend\src\returns","backend\src\marketplace",
    "backend\src\notifications","backend\src\analytics","backend\src\audit","backend\src\billing",
    "backend\src\common\guards","backend\src\common\interceptors","backend\src\common\decorators",
    "backend\src\common\utils","backend\src\config","backend\prisma","backend\test",
    "frontend\lib\config","frontend\lib\core","frontend\lib\data","frontend\lib\domain",
    "frontend\lib\presentation\auth","frontend\lib\presentation\dashboard","frontend\lib\presentation\scanner",
    "frontend\lib\presentation\recording","frontend\lib\presentation\upload","frontend\lib\presentation\orders",
    "frontend\lib\presentation\claims","frontend\lib\presentation\returns","frontend\lib\presentation\evidence",
    "frontend\lib\presentation\admin","frontend\lib\presentation\analytics","frontend\lib\presentation\settings",
    "frontend\lib\presentation\supervisor",
    "docs","scripts",".github\workflows"
)
foreach ($f in $folders) { New-Item -ItemType Directory -Path "$PROJECT_ROOT\$f" -Force | Out-Null }

Write-Host "Folder structure created." -ForegroundColor Green
```

### 10.2 Backend setup

```powershell
Set-Location "$PROJECT_ROOT\backend"

npx @nestjs/cli@latest new . --strict --package-manager npm --skip-git

npm install @nestjs/common @nestjs/core @nestjs/platform-express `
  @nestjs/config @nestjs/swagger @nestjs/schedule @nestjs/throttler `
  @prisma/client prisma `
  @clerk/backend svix `
  bullmq ioredis `
  @aws-sdk/client-s3 @aws-sdk/s3-request-presigner `
  razorpay `
  class-validator class-transformer helmet compression `
  winston nest-winston

npm install -D @types/node typescript ts-node jest supertest

npx prisma init

@'
NODE_ENV=development
PORT=3000
API_VERSION=v1

# Neon PostgreSQL — used from local dev onward, no local Postgres ever
DATABASE_URL=postgresql://user:pass@YOUR-NEON-HOST/db?sslmode=require

REDIS_URL=redis://localhost:6379

# Clerk
CLERK_SECRET_KEY=sk_test_xxx
CLERK_PUBLISHABLE_KEY=pk_test_xxx
CLERK_AUTHORIZED_PARTIES=http://localhost:3000
CLERK_WEBHOOK_SIGNING_SECRET=whsec_xxx

# Backblaze B2 (S3-compatible) — used from local dev onward, no local file storage ever
B2_KEY_ID=xxx
B2_APPLICATION_KEY=xxx
B2_BUCKET=lossdefender-v1-media
B2_ENDPOINT=https://s3.us-west-002.backblazeb2.com
B2_SIGNED_URL_TTL=900

# Razorpay
RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx

# Security
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX=100
'@ | Out-File -FilePath ".env" -Encoding utf8

Copy-Item ".env" ".env.example"
(Get-Content ".env.example") -replace '=.+', '=' | Set-Content ".env.example"

Write-Host "Backend scaffolded." -ForegroundColor Green
```

### 10.3 First migration

```powershell
Set-Location "$PROJECT_ROOT\backend"
# paste the schema from §7 into prisma/schema.prisma first
npx prisma migrate dev --name init
npx prisma generate
```

### 10.4 Flutter setup

```powershell
Set-Location "$PROJECT_ROOT\frontend"

flutter create --org com.lossdefender --project-name loss_defender_v1 `
  --platforms=android,ios,web,windows .

flutter pub add flutter_riverpod dio retrofit drift drift_flutter `
  sqlite3_flutter_libs flutter_secure_storage camera video_player `
  mobile_scanner freezed_annotation json_annotation permission_handler

flutter pub add -d build_runner freezed json_serializable `
  retrofit_generator drift_dev riverpod_generator

Write-Host "Flutter project scaffolded." -ForegroundColor Green
```

### 10.5 Daily development commands

```powershell
# --- Backend ---
Set-Location "$PROJECT_ROOT\backend"
npm run start:dev

# --- Flutter (pick target device) ---
Set-Location "$PROJECT_ROOT\frontend"
flutter run -d chrome            # Web
flutter run -d windows           # Windows desktop
flutter run                       # Connected Android/iOS device or emulator

# --- Prisma ---
npx prisma studio                 # Visual DB browser against Neon
npx prisma migrate dev --name <change_description>

# --- Git workflow ---
git add .
git commit -m "feat: <description>"
git push origin main
```

### 10.6 Release builds

```powershell
$API = "https://api.lossdefender.in/api/v1"

flutter build apk --release --dart-define=API_BASE_URL=$API
flutter build appbundle --release --dart-define=API_BASE_URL=$API   # Play Store
flutter build ios --release --dart-define=API_BASE_URL=$API          # requires macOS/Xcode
flutter build web --release --dart-define=API_BASE_URL=$API
flutter build windows --release --dart-define=API_BASE_URL=$API
```

---

## 11. Deployment Guide — ExCloud VPS

**Only after** local development and full testing (§13) are complete.

| Component | Choice |
|---|---|
| Compute | ExCloud VPS — Ubuntu LTS, 4 vCPU / 8GB RAM minimum |
| Runtime | Docker + Docker Compose |
| Proxy | Nginx (SSL) + PM2 inside the container |
| Database | Neon (already in use — no migration needed, same connection just pointed at prod branch) |
| Storage | Backblaze B2 (already in use — same bucket or a prod-specific bucket) |
| CDN/WAF | Cloudflare in front of the VPS |

### 11.1 Deployment steps

```powershell
# From your local machine, build and push, or SSH into the VPS and pull.
# Example: SSH workflow
ssh youruser@your-excloud-ip

# On the VPS:
git clone https://github.com/sanjeetdayma83/loss-defender-v1.git
cd loss-defender-v1/backend
cp .env.example .env   # then fill in production values
docker compose up -d --build
docker compose exec api npx prisma migrate deploy
```

### 11.2 CI/CD (GitHub Actions, high level)

```
push to main → lint + unit tests → build Docker image → run prisma migrate deploy
  against staging → smoke test → blue-green deploy to prod → health check → traffic switch
```

### 11.3 Nginx (SSL termination, reverse proxy to the Node container)

```nginx
server {
  listen 443 ssl;
  server_name api.lossdefender.in;
  ssl_certificate     /etc/letsencrypt/live/api.lossdefender.in/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/api.lossdefender.in/privkey.pem;

  location / {
    proxy_pass http://localhost:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

---

## 12. Security Model — Rules That Must Never Be Broken

These are not generic best practices — they are specific fixes for specific incidents found while auditing the earlier version of this exact product. Building them in from commit #1 means this version never has to fix them later.

| # | Rule | Why (what happened before) |
|---|---|---|
| 1 | `companyId` is **always** derived server-side from the authenticated user's session — never accepted from a request body, query string, or URL path parameter. | An earlier build let `companyId` be passed by the client on several endpoints (including `/companies/:id`, `/warehouses/company/:companyId`), letting any logged-in user read or even delete another tenant's data by guessing a UUID. |
| 2 | The Scanner module must contain **real** barcode/SKU/quantity/duplicate-scan validation from the first commit — never a placeholder that returns a hardcoded "verified" response "to unblock the frontend." | A stub scanner endpoint that always returned `status: VERIFIED` shipped to the main branch of an earlier build and silently defeated the entire product's core promise. |
| 3 | Every webhook (Clerk, Razorpay, marketplace providers) verifies its HMAC/Svix signature against the **raw request body bytes**, captured via `rawBody: true` at bootstrap — never against a re-serialized `JSON.stringify(parsedBody)`. | Re-serializing a parsed object rarely reproduces the exact bytes the sender signed, causing real, correctly-signed webhooks to be silently rejected in production — this exact bug was found live in an earlier marketplace-webhook implementation. |
| 4 | `PermissionsGuard`/role-check logic **fails closed**: if a role or permission can't be determined, throw `403` — never default to any real role "just so the request doesn't crash." | An earlier guard defaulted an unauthenticated context to `packing_operator` instead of denying — a latent privilege-escalation risk. |
| 5 | Cross-tenant admin/impersonation features (if built at all) are **disabled by default** and only enabled by an explicit allowlist env var — never "unrestricted unless configured otherwise." | An earlier super-admin "act as tenant" feature had no restriction at all unless a specific env var was set, and that var wasn't documented, so a standard deployment shipped it wide open. |
| 6 | Every module that's wired into a route must actually be registered in the app module. Don't leave a "fully built but unregistered" module in the tree with no guards, expecting to wire it up "later." | An earlier build had a fully-coded, completely unauthenticated AI module sitting in the source tree, never registered — a real risk the moment someone flips it on without re-adding guards. |
| 7 | No feature ships as an empty folder of 0-byte placeholder files pretending to be "in progress." If a module (e.g. Claims) isn't built yet, it's simply not listed as done anywhere — not scaffolded and forgotten. | An earlier build's entire Claims module was empty stub files while internal docs listed it as a completed, high-priority feature. |
| 8 | No password is ever stored, requested, or transmitted by this backend. Clerk owns 100% of credential handling; the backend only ever sees a verified session token. | Removes an entire category of risk (password storage, reset-token generation, brute-force windows) rather than hardening it. |
| 9 | All object storage is private; every read/write to B2 goes through a signed URL with a 5–15 minute TTL generated server-side, never a public bucket URL. | Standard, was already correct in earlier builds — kept as a hard rule. |
| 10 | Dependencies are kept current; run a vulnerability scan (`npm audit` or equivalent) before every release, not just at project kickoff. | Earlier builds accumulated known-critical CVEs (e.g. an outdated `tar` transitive dependency) that sat unpatched for weeks. |

---

## 13. Testing Strategy

| Layer | Tools | Coverage target |
|---|---|---|
| Unit (backend) | Jest | >80% on services/guards |
| Integration (backend) | Jest + Supertest | >70%, incl. tenant-isolation tests (try to access another company's data and expect 403/404) |
| Contract | OpenAPI conformance | 100% of endpoints |
| Flutter widget/integration | `flutter_test` | >70%, incl. offline-queue behavior |
| E2E happy path | Manual or Playwright (web) | Full flow: invite → accept → scan → record → upload → dispatch → claim → decide |

**Security-specific tests to run before every release** (directly from §12):
- Attempt to pass a foreign `companyId` in body/query/path on every mutating endpoint → expect it to be ignored or rejected.
- Scan an order with a wrong/duplicate barcode → expect a real rejection, not a hardcoded success.
- Send a webhook with a correct signature over the real payload → expect acceptance; send one with a tampered body → expect rejection.
- Hit any permission-checked route with a malformed/missing session → expect `401/403`, never a default role.

---

## 14. Go-Live Checklist

```
☐ Neon production branch provisioned, connection pooling configured
☐ Backblaze B2 production bucket private, lifecycle rules set
☐ Clerk production instance keys swapped in (not test keys)
☐ Razorpay live keys swapped in, webhook endpoint registered
☐ Redis available and health-checked
☐ SSL valid, HSTS enabled, Cloudflare in front
☐ .env complete on the VPS, no secrets committed to git
☐ CI/CD green on main
☐ Backup/restore tested end-to-end
☐ Monitoring & alerting live
☐ All 10 rules in §12 re-verified against the actual deployed code, not just this document
☐ Load test passed for expected concurrent operator count
☐ Legal/privacy policy published
```

---

## 15. Future Roadmap

| Feature | Target |
|---|---|
| AI-assisted claim evidence summary | v1.3 |
| Warehouse heatmaps / bottleneck detection | v2.0 |
| Live multi-station monitoring wall | v2.0 |
| Multi-region deployment | v2.0 |
| White-label / reseller mode | v2.0 |
