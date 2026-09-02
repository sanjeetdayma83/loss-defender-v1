const { PrismaClient } = require("@prisma/client");
const { createHash, randomBytes } = require("crypto");

const prisma = new PrismaClient();

async function main() {
  const email = (process.env.SEED_EMAIL || "owner@test.ldp").toLowerCase();
  const companyName = process.env.SEED_COMPANY || "Demo Warehouse Co";

  const company = await prisma.company.upsert({
    where: { email },
    update: {},
    create: {
      companyName,
      email,
      phone: "9999999999",
      status: "active",
    },
  });

  const user = await prisma.user.upsert({
    where: { email },
    update: {
      status: "active",
      role: "company_admin",
      companyId: company.id,
    },
    create: {
      email,
      name: "Company Admin",
      phone: "9999999999",
      role: "company_admin",
      status: "active",
      companyId: company.id,
    },
  });

  const raw = randomBytes(32).toString("hex");
  const tokenHash = createHash("sha256").update(raw).digest("hex");
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  await prisma.inviteToken.create({
    data: { userId: user.id, tokenHash, expiresAt },
  });

  console.log("Company:", company.id);
  console.log("User:", user.id, user.email, user.role);
  console.log("clerkId:", user.clerkId || "(null — need accept-invite)");
  console.log("INVITE_TOKEN:", raw);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
