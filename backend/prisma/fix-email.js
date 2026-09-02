const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();

async function run() {
  try {
    const u = await p.user.update({
      where: { email: "admin@lossdefender.local" },
      data: { email: "admin@lossdefender.in" },
    });
    console.log("Updated:", u.id, u.email, u.status);
  } catch (e) {
    console.error(e.message || e);
  } finally {
    await p.$disconnect();
  }
}
run();