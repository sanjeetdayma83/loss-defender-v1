import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    user: AuthUser,
    opts: { action?: string; entityType?: string; page?: number; limit?: number } = {},
  ) {
    const page = Math.max(1, opts.page ?? 1);
    const limit = Math.min(100, Math.max(1, opts.limit ?? 50));
    const where = tenantWhere(user.companyId, {
      ...(opts.action && { action: opts.action }),
      ...(opts.entityType && { entityType: opts.entityType }),
    });

    const [total, rows] = await Promise.all([
      this.prisma.auditLog.count({ where }),
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return { rows, meta: { page, limit, total } };
  }
}