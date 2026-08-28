import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async kpis(user: AuthUser) {
    const cid = user.companyId;
    const [
      ordersTotal,
      ordersDispatched,
      ordersClaimed,
      ordersReturned,
      evidenceReady,
      openClaims,
      activeUsers,
      warehouses,
    ] = await Promise.all([
      this.prisma.order.count({ where: tenantWhere(cid) }),
      this.prisma.order.count({ where: tenantWhere(cid, { status: "dispatched" }) }),
      this.prisma.order.count({ where: tenantWhere(cid, { status: "claimed" }) }),
      this.prisma.order.count({ where: tenantWhere(cid, { status: "returned" }) }),
      this.prisma.order.count({ where: tenantWhere(cid, { status: "evidence_ready" }) }),
      this.prisma.claim.count({
        where: tenantWhere(cid, { status: { in: ["open", "under_review", "investigating"] } }),
      }),
      this.prisma.user.count({ where: tenantWhere(cid, { status: "active" }) }),
      this.prisma.warehouse.count({ where: tenantWhere(cid, { status: "active" }) }),
    ]);

    const withEvidence = await this.prisma.order.count({
      where: tenantWhere(cid, { evidenceId: { not: null } }),
    });

    const evidenceCoverage =
      ordersTotal > 0 ? Math.round((withEvidence / ordersTotal) * 1000) / 10 : 0;

    return {
      ordersTotal,
      ordersDispatched,
      ordersClaimed,
      ordersReturned,
      evidenceReady,
      openClaims,
      activeUsers,
      warehouses,
      evidenceCoveragePercent: evidenceCoverage,
    };
  }
}