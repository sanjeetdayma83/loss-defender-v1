import {
  Injectable, NotFoundException, BadRequestException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationsService } from "../notifications/notifications.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class ClaimsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async list(
    user: AuthUser,
    opts: { status?: string; page?: number; limit?: number } = {},
  ) {
    const page = Math.max(1, opts.page ?? 1);
    const limit = Math.min(100, Math.max(1, opts.limit ?? 20));
    const where = tenantWhere(user.companyId, {
      ...(opts.status && { status: opts.status as any }),
    });

    const [total, rows] = await Promise.all([
      this.prisma.claim.count({ where }),
      this.prisma.claim.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          order: {
            select: {
              id: true, marketplaceOrderId: true, status: true, awb: true, evidenceId: true,
            },
          },
        },
      }),
    ]);
    return { rows, meta: { page, limit, total } };
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.claim.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: {
        order: {
          include: {
            evidence: true,
            recording: { select: { id: true, status: true, segmentCount: true } },
          },
        },
      },
    });
    if (!row) throw new NotFoundException("Claim not found");
    return row;
  }

  async create(
    user: AuthUser,
    dto: { orderId: string; reason: string; marketplace: string; description?: string },
  ) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: dto.orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    const claim = await this.prisma.claim.create({
      data: {
        companyId: user.companyId,
        orderId: dto.orderId,
        reason: dto.reason,
        marketplace: dto.marketplace as any,
        description: dto.description,
        status: "open",
      },
    });

    await this.prisma.order.update({
      where: { id: dto.orderId },
      data: { status: "claimed" },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "claim.create",
        entityType: "Claim",
        entityId: claim.id,
        afterState: { orderId: dto.orderId, reason: dto.reason },
      },
    });

    return claim;
  }

  async decide(
    user: AuthUser,
    id: string,
    dto: { decision: "approved" | "rejected"; note?: string },
  ) {
    const claim = await this.prisma.claim.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!claim) throw new NotFoundException("Claim not found");
    if (["approved", "rejected", "closed"].includes(claim.status)) {
      throw new BadRequestException(`Claim already ${claim.status}`);
    }

    const updated = await this.prisma.claim.update({
      where: { id },
      data: {
        status: dto.decision === "approved" ? "approved" : "rejected",
        decision: dto.decision,
        decidedBy: user.id,
        decidedAt: new Date(),
        description: dto.note
          ? `${claim.description || ""}\n[Decision note]: ${dto.note}`.trim()
          : claim.description,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "claim.decide",
        entityType: "Claim",
        entityId: id,
        afterState: { decision: dto.decision },
      },
    });

    await this.notifications.enqueue(user.companyId, "in_app", {
      type: "claim.decided",
      claimId: id,
      decision: dto.decision,
    }, user.id);

    return updated;
  }
}