import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

export type CreateClaimDto = {
  orderId: string;
  reason: string;
  marketplace: "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce" | "manual";
  description?: string;
  attachments?: Record<string, unknown>;
};

export type DecideClaimDto = {
  decision: "approved" | "rejected" | "escalated";
  note?: string;
};

const CLAIM_TRANSITIONS: Record<string, string[]> = {
  open: ["under_review", "investigating", "closed"],
  under_review: ["investigating", "approved", "rejected", "escalated", "closed"],
  investigating: ["approved", "rejected", "escalated", "closed"],
  approved: ["closed"],
  rejected: ["closed"],
  escalated: ["investigating", "approved", "rejected", "closed"],
  closed: [],
};

@Injectable()
export class ClaimsService {
  constructor(private readonly prisma: PrismaService) {}

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
              id: true,
              marketplaceOrderId: true,
              status: true,
              awb: true,
              evidenceId: true,
            },
          },
        },
      }),
    ]);

    return { rows, meta: { page, limit, total } };
  }

  async getOne(user: AuthUser, id: string) {
    const claim = await this.prisma.claim.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: {
        order: {
          select: {
            id: true,
            marketplaceOrderId: true,
            status: true,
            items: true,
            awb: true,
            courier: true,
            evidenceId: true,
            recordingId: true,
          },
        },
      },
    });
    if (!claim) throw new NotFoundException("Claim not found");
    return claim;
  }

  async create(user: AuthUser, dto: CreateClaimDto) {
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
        attachments: dto.attachments,
        status: "open",
      },
    });

    // Mark order as claimed if still in post-dispatch state
    if (["dispatched", "shipped"].includes(order.status)) {
      await this.prisma.order.update({
        where: { id: order.id },
        data: { status: "claimed" },
      });
    }

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

  async transition(user: AuthUser, id: string, status: string) {
    const claim = await this.prisma.claim.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!claim) throw new NotFoundException("Claim not found");

    const allowed = CLAIM_TRANSITIONS[claim.status] ?? [];
    if (!allowed.includes(status)) {
      throw new BadRequestException(
        `Invalid claim transition: ${claim.status} → ${status}`,
      );
    }

    const updated = await this.prisma.claim.update({
      where: { id },
      data: { status: status as any },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "claim.transition",
        entityType: "Claim",
        entityId: id,
        beforeState: { status: claim.status },
        afterState: { status },
      },
    });

    return updated;
  }

  async decide(user: AuthUser, id: string, dto: DecideClaimDto) {
    const claim = await this.prisma.claim.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!claim) throw new NotFoundException("Claim not found");

    const targetStatus = dto.decision; // approved | rejected | escalated
    const allowed = CLAIM_TRANSITIONS[claim.status] ?? [];
    if (!allowed.includes(targetStatus)) {
      throw new BadRequestException(
        `Cannot decide '${targetStatus}' from status '${claim.status}'`,
      );
    }

    const updated = await this.prisma.claim.update({
      where: { id },
      data: {
        status: targetStatus as any,
        decision: dto.note ? `${dto.decision}: ${dto.note}` : dto.decision,
        decidedBy: user.id,
        decidedAt: new Date(),
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "claim.decide",
        entityType: "Claim",
        entityId: id,
        afterState: { decision: dto.decision, note: dto.note },
      },
    });

    return updated;
  }
}