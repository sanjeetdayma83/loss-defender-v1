const { PrismaClient } = require("@prisma/client");
const p = new PrismaClient();
async function run() {
  const id = "b46ed5cc-d562-4c07-998a-cbe0c9bdbcad";
  const o = await p.order.update({
    where: { id },
    data: { status: "packing", assignedOperatorId: "7f621bd4-c7e7-4ff5-9b98-a39e1782d507" },
  });
  console.log("Updated:", o.id, o.status, o.assignedOperatorId);
  await p.$disconnect();
}
run().catch(e => { console.error(e); process.exit(1); });