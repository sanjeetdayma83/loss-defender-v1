const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

async function run() {
  try {
    // Agar yeh clerkId kisi aur pe lagi ho to clear
    await p.user.updateMany({
      where: { clerkId: "user_3IeCcEn9Cl3wh0czqNZqFnhA4jX" },
      data: { clerkId: null },
    });

    const u = await p.user.update({
      where: { id: "7f621bd4-c7e7-4ff5-9b98-a39e1782d507" },
      data: {
        email: "sanjeetdayma83@gmail.com",
        clerkId: "user_3IeCcEn9Cl3wh0czqNZqFnhA4jX",
        status: "active",
        lastLoginAt: new Date(),
      },
    });
    console.log("Linked OK:");
    console.log("  id      :", u.id);
    console.log("  email   :", u.email);
    console.log("  clerkId :", u.clerkId);
    console.log("  role    :", u.role);
    console.log("  status  :", u.status);
    console.log("  company :", u.companyId);
  } catch (e) {
    console.error(e.message || e);
  } finally {
    await p.$disconnect();
  }
}
run();