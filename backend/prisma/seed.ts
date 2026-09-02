/**
 * LOSS DEFENDER V1 — Demo seed
 * Creates: Company + Warehouse + Station + Admin + Operator + sample Order
 * Prints invite token for operator (accept via POST /auth/accept-invite)
 *
 * Run:  npx ts-node --transpile-only prisma/seed.ts
 * Or:   npm run seed
 *
 * Optional env:
 *   SEED_ADMIN_EMAIL=admin@demo.lossdefender.in
 *   SEED_ADMIN_CLERK_ID=user_xxx   ← if set, admin is active + linked (skip invite for admin)
 *   SEED_OPERATOR_EMAIL=operator@demo.lossdefender.in
 */
import { PrismaClient, Role, Plan, Status, UserStatus } from "@prisma/client";
import { createHash, randomBytes } from "crypto";

const prisma = new PrismaClient();

function inviteToken(): { raw: string; hash: string; expiresAt: Date } {
  const raw = randomBytes(32).toString("hex");
  const hash = createHash("sha256").update(raw).digest("hex");
  const expiresAt = new Date(Date.now() + 72 * 60 * 60 * 1000);
  return { raw, hash, expiresAt };
}

async function main() {
  const adminEmail = (process.env.SEED_ADMIN_EMAIL || "admin@demo.lossdefender.in").toLowerCase();
  const operatorEmail = (process.env.SEED_OPERATOR_EMAIL || "operator@demo.lossdefender.in").toLowerCase();
  const adminClerkId = process.env.SEED_ADMIN_CLERK_ID || null;

  console.log("=== LOSS DEFENDER V1 SEED ===");

  // Idempotent: reuse company by email
  let company = await prisma.company.findUnique({ where: { email: "demo@lossdefender.in" } });
  if (!company) {
    company = await prisma.company.create({
      data: {
        companyName: "Demo Warehouse Pvt Ltd",
        email: "demo@lossdefender.in",
        phone: "+919999000001",
        plan: Plan.professional,
        status: Status.active,
        timezone: "Asia/Kolkata",
        currency: "INR",
        storageQuota: BigInt(53687091200),
      },
    });
    console.log("Created company:", company.id);
  } else {
    console.log("Company exists:", company.id);
  }

  let warehouse = await prisma.warehouse.findFirst({
    where: { companyId: company.id, code: "WH-01" },
  });
  if (!warehouse) {
    warehouse = await prisma.warehouse.create({
      data: {
        companyId: company.id,
        name: "Main Warehouse",
        code: "WH-01",
        address: { line1: "Industrial Area", city: "Jaipur", state: "Rajasthan", pincode: "302001" },
        city: "Jaipur",
        state: "Rajasthan",
        country: "India",
        timezone: "Asia/Kolkata",
        status: Status.active,
      },
    });
    console.log("Created warehouse:", warehouse.id);
  }

  let station = await prisma.station.findFirst({
    where: { warehouseId: warehouse.id, stationCode: "ST-01" },
  });
  if (!station) {
    station = await prisma.station.create({
      data: {
        warehouseId: warehouse.id,
        stationName: "Pack Station 1",
        stationCode: "ST-01",
        status: "online",
      },
    });
    console.log("Created station:", station.id);
  }

  // Admin
  let admin = await prisma.user.findUnique({ where: { email: adminEmail } });
  if (!admin) {
    admin = await prisma.user.create({
      data: {
        companyId: company.id,
        name: "Demo Admin",
        email: adminEmail,
        phone: "+919999000002",
        role: Role.company_admin,
        warehouseId: warehouse.id,
        status: adminClerkId ? UserStatus.active : UserStatus.pending,
        clerkId: adminClerkId,
        lastLoginAt: adminClerkId ? new Date() : null,
      },
    });
    console.log("Created admin:", admin.id, adminEmail);
  } else {
    console.log("Admin exists:", admin.id);
    if (adminClerkId && !admin.clerkId) {
      admin = await prisma.user.update({
        where: { id: admin.id },
        data: { clerkId: adminClerkId, status: UserStatus.active, lastLoginAt: new Date() },
      });
      console.log("Linked SEED_ADMIN_CLERK_ID to admin");
    }
  }

  // Operator + invite
  let operator = await prisma.user.findUnique({ where: { email: operatorEmail } });
  let operatorInviteRaw: string | null = null;
  if (!operator) {
    operator = await prisma.user.create({
      data: {
        companyId: company.id,
        name: "Demo Operator",
        email: operatorEmail,
        phone: "+919999000003",
        role: Role.packing_operator,
        warehouseId: warehouse.id,
        status: UserStatus.pending,
      },
    });
    const inv = inviteToken();
    await prisma.inviteToken.create({
      data: { userId: operator.id, tokenHash: inv.hash, expiresAt: inv.expiresAt },
    });
    operatorInviteRaw = inv.raw;
    console.log("Created operator:", operator.id, operatorEmail);
  } else {
    console.log("Operator exists:", operator.id);
    // Fresh invite if still pending and no unused token
    if (operator.status === "pending") {
      const inv = inviteToken();
      await prisma.inviteToken.create({
        data: { userId: operator.id, tokenHash: inv.hash, expiresAt: inv.expiresAt },
      });
      operatorInviteRaw = inv.raw;
    }
  }

  // Sample order
  let order = await prisma.order.findFirst({
    where: { companyId: company.id, marketplaceOrderId: "DEMO-ORDER-001" },
  });
  if (!order) {
    order = await prisma.order.create({
      data: {
        companyId: company.id,
        warehouseId: warehouse.id,
        marketplace: "manual",
        marketplaceOrderId: "DEMO-ORDER-001",
        status: "queued",
        assignedOperatorId: operator.id,
        stationId: station.id,
        items: [
          { sku: "SKU-RED-TEE", qty: 2, name: "Red T-Shirt", scannedQty: 0, status: "pending" },
          { sku: "SKU-BLUE-JEANS", qty: 1, name: "Blue Jeans", scannedQty: 0, status: "pending" },
        ],
      },
    });
    console.log("Created sample order:", order.id);
  } else {
    console.log("Sample order exists:", order.id);
  }

  console.log("\n========== SEED OUTPUT (save this) ==========");
  console.log("COMPANY_ID=", company.id);
  console.log("WAREHOUSE_ID=", warehouse.id);
  console.log("STATION_ID=", station.id);
  console.log("ADMIN_ID=", admin.id);
  console.log("ADMIN_EMAIL=", adminEmail);
  console.log("OPERATOR_ID=", operator.id);
  console.log("OPERATOR_EMAIL=", operatorEmail);
  console.log("ORDER_ID=", order.id);
  if (adminClerkId) {
    console.log("ADMIN linked to Clerk:", adminClerkId);
  } else {
    console.log("ADMIN is pending — set SEED_ADMIN_CLERK_ID or accept invite for admin");
  }
  if (operatorInviteRaw) {
    console.log("OPERATOR_INVITE_TOKEN=", operatorInviteRaw);
    console.log(
      "Accept: POST /api/v1/auth/accept-invite",
      JSON.stringify({ inviteToken: operatorInviteRaw, clerkId: "<CLERK_USER_ID>", email: operatorEmail }),
    );
  }
  console.log("=============================================\n");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
