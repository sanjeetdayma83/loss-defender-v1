-- CreateEnum
CREATE TYPE "Role" AS ENUM ('super_admin', 'company_admin', 'warehouse_manager', 'supervisor', 'packing_operator', 'qc_operator', 'claims_executive', 'marketplace_manager', 'viewer', 'auditor');

-- CreateEnum
CREATE TYPE "Plan" AS ENUM ('free', 'starter', 'professional', 'enterprise');

-- CreateEnum
CREATE TYPE "Status" AS ENUM ('active', 'suspended', 'deleted');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('pending', 'active', 'suspended', 'deleted');

-- CreateEnum
CREATE TYPE "StationStatus" AS ENUM ('online', 'offline', 'maintenance', 'inactive');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('synced', 'queued', 'packing', 'recording', 'scanned', 'evidence_ready', 'dispatched', 'shipped', 'claimed', 'returned', 'closed');

-- CreateEnum
CREATE TYPE "RecordingStatus" AS ENUM ('started', 'paused', 'completed', 'failed');

-- CreateEnum
CREATE TYPE "EvidenceStatus" AS ENUM ('processing', 'ready', 'failed');

-- CreateEnum
CREATE TYPE "ClaimStatus" AS ENUM ('open', 'under_review', 'investigating', 'approved', 'rejected', 'escalated', 'closed');

-- CreateEnum
CREATE TYPE "Marketplace" AS ENUM ('amazon', 'flipkart', 'meesho', 'shopify', 'woocommerce', 'manual');

-- CreateTable
CREATE TABLE "Company" (
    "id" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "gst" TEXT,
    "pan" TEXT,
    "address" JSONB,
    "timezone" TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "plan" "Plan" NOT NULL DEFAULT 'free',
    "storageUsed" BIGINT NOT NULL DEFAULT 0,
    "storageQuota" BIGINT NOT NULL DEFAULT 5368709120,
    "status" "Status" NOT NULL DEFAULT 'active',
    "logo" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Company_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "clerkId" TEXT,
    "companyId" TEXT NOT NULL,
    "employeeId" TEXT,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT,
    "role" "Role" NOT NULL DEFAULT 'packing_operator',
    "warehouseId" TEXT,
    "stationId" TEXT,
    "status" "UserStatus" NOT NULL DEFAULT 'pending',
    "profilePhoto" TEXT,
    "joiningDate" TIMESTAMP(3),
    "lastLoginAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "InviteToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "usedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InviteToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Warehouse" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "address" JSONB NOT NULL,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "country" TEXT NOT NULL DEFAULT 'India',
    "timezone" TEXT NOT NULL,
    "status" "Status" NOT NULL DEFAULT 'active',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Warehouse_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Station" (
    "id" TEXT NOT NULL,
    "warehouseId" TEXT NOT NULL,
    "stationName" TEXT NOT NULL,
    "stationCode" TEXT NOT NULL,
    "cameraConfig" JSONB,
    "scannerConfig" JSONB,
    "printerConfig" JSONB,
    "status" "StationStatus" NOT NULL DEFAULT 'offline',
    "lastHeartbeatAt" TIMESTAMP(3),

    CONSTRAINT "Station_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Order" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "warehouseId" TEXT,
    "marketplace" "Marketplace" NOT NULL DEFAULT 'manual',
    "marketplaceOrderId" TEXT,
    "status" "OrderStatus" NOT NULL DEFAULT 'synced',
    "items" JSONB NOT NULL,
    "assignedOperatorId" TEXT,
    "stationId" TEXT,
    "recordingId" TEXT,
    "evidenceId" TEXT,
    "awb" TEXT,
    "courier" TEXT,
    "dispatchedAt" TIMESTAMP(3),
    "deliveredAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Order_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Recording" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "operatorId" TEXT NOT NULL,
    "stationId" TEXT,
    "status" "RecordingStatus" NOT NULL DEFAULT 'started',
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "stoppedAt" TIMESTAMP(3),
    "segmentCount" INTEGER NOT NULL DEFAULT 0,
    "b2KeyPrefix" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Recording_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecordingSegment" (
    "id" TEXT NOT NULL,
    "recordingId" TEXT NOT NULL,
    "sequence" INTEGER NOT NULL,
    "b2Key" TEXT NOT NULL,
    "checksum" TEXT NOT NULL,
    "sizeBytes" BIGINT NOT NULL,
    "uploadedAt" TIMESTAMP(3),

    CONSTRAINT "RecordingSegment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Evidence" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "recordingId" TEXT NOT NULL,
    "status" "EvidenceStatus" NOT NULL DEFAULT 'processing',
    "frameCount" INTEGER NOT NULL DEFAULT 0,
    "frames" JSONB,
    "checksum" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Evidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Claim" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "marketplace" "Marketplace" NOT NULL,
    "description" TEXT,
    "status" "ClaimStatus" NOT NULL DEFAULT 'open',
    "decision" TEXT,
    "decidedBy" TEXT,
    "decidedAt" TIMESTAMP(3),
    "attachments" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Claim_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Return" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "unboxingRecordingId" TEXT,
    "condition" TEXT,
    "decision" TEXT,
    "decidedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Return_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MarketplaceAccount" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "marketplace" "Marketplace" NOT NULL,
    "accessToken" TEXT NOT NULL,
    "refreshToken" TEXT,
    "webhookSecret" TEXT,
    "status" "Status" NOT NULL DEFAULT 'active',
    "lastSyncAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MarketplaceAccount_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "userId" TEXT,
    "channel" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "sentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "actorId" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "beforeState" JSONB,
    "afterState" JSONB,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Session" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "clerkSessionId" TEXT NOT NULL,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "revokedAt" TIMESTAMP(3),

    CONSTRAINT "Session_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BillingSubscription" (
    "id" TEXT NOT NULL,
    "companyId" TEXT NOT NULL,
    "razorpaySubId" TEXT NOT NULL,
    "plan" "Plan" NOT NULL,
    "status" TEXT NOT NULL,
    "currentPeriodStart" TIMESTAMP(3) NOT NULL,
    "currentPeriodEnd" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BillingSubscription_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Company_email_key" ON "Company"("email");

-- CreateIndex
CREATE INDEX "Company_status_idx" ON "Company"("status");

-- CreateIndex
CREATE UNIQUE INDEX "User_clerkId_key" ON "User"("clerkId");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_companyId_status_idx" ON "User"("companyId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "InviteToken_tokenHash_key" ON "InviteToken"("tokenHash");

-- CreateIndex
CREATE INDEX "Warehouse_companyId_status_idx" ON "Warehouse"("companyId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "Warehouse_companyId_code_key" ON "Warehouse"("companyId", "code");

-- CreateIndex
CREATE UNIQUE INDEX "Station_warehouseId_stationCode_key" ON "Station"("warehouseId", "stationCode");

-- CreateIndex
CREATE UNIQUE INDEX "Order_recordingId_key" ON "Order"("recordingId");

-- CreateIndex
CREATE UNIQUE INDEX "Order_evidenceId_key" ON "Order"("evidenceId");

-- CreateIndex
CREATE INDEX "Order_companyId_status_idx" ON "Order"("companyId", "status");

-- CreateIndex
CREATE INDEX "Order_marketplaceOrderId_idx" ON "Order"("marketplaceOrderId");

-- CreateIndex
CREATE INDEX "Order_companyId_createdAt_idx" ON "Order"("companyId", "createdAt");

-- CreateIndex
CREATE INDEX "Recording_companyId_idx" ON "Recording"("companyId");

-- CreateIndex
CREATE UNIQUE INDEX "RecordingSegment_recordingId_sequence_key" ON "RecordingSegment"("recordingId", "sequence");

-- CreateIndex
CREATE UNIQUE INDEX "Evidence_recordingId_key" ON "Evidence"("recordingId");

-- CreateIndex
CREATE INDEX "Evidence_companyId_idx" ON "Evidence"("companyId");

-- CreateIndex
CREATE INDEX "Claim_companyId_status_idx" ON "Claim"("companyId", "status");

-- CreateIndex
CREATE INDEX "Return_companyId_idx" ON "Return"("companyId");

-- CreateIndex
CREATE UNIQUE INDEX "MarketplaceAccount_companyId_marketplace_key" ON "MarketplaceAccount"("companyId", "marketplace");

-- CreateIndex
CREATE INDEX "Notification_companyId_status_idx" ON "Notification"("companyId", "status");

-- CreateIndex
CREATE INDEX "AuditLog_companyId_createdAt_idx" ON "AuditLog"("companyId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_actorId_action_idx" ON "AuditLog"("actorId", "action");

-- CreateIndex
CREATE UNIQUE INDEX "Session_clerkSessionId_key" ON "Session"("clerkSessionId");

-- CreateIndex
CREATE INDEX "Session_userId_idx" ON "Session"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "BillingSubscription_companyId_key" ON "BillingSubscription"("companyId");

-- CreateIndex
CREATE UNIQUE INDEX "BillingSubscription_razorpaySubId_key" ON "BillingSubscription"("razorpaySubId");

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Warehouse" ADD CONSTRAINT "Warehouse_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Station" ADD CONSTRAINT "Station_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_warehouseId_fkey" FOREIGN KEY ("warehouseId") REFERENCES "Warehouse"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_recordingId_fkey" FOREIGN KEY ("recordingId") REFERENCES "Recording"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Order" ADD CONSTRAINT "Order_evidenceId_fkey" FOREIGN KEY ("evidenceId") REFERENCES "Evidence"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RecordingSegment" ADD CONSTRAINT "RecordingSegment_recordingId_fkey" FOREIGN KEY ("recordingId") REFERENCES "Recording"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Claim" ADD CONSTRAINT "Claim_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Claim" ADD CONSTRAINT "Claim_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "Order"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MarketplaceAccount" ADD CONSTRAINT "MarketplaceAccount_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BillingSubscription" ADD CONSTRAINT "BillingSubscription_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
