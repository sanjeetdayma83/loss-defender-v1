import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    user: AuthUser,
    opts: { status?: string; warehouseId?: string; page?: number; limit?: number } = {},
  ) {
    const page = Math.max(1, opts.page ?? 1);
    const limit = Math.min(100, Math.max(1, opts.limit ?? 20));
    const where = tenantWhere(user.companyId, {
      ...(opts.status && { status: opts.status as any }),
      ...(opts.warehouseId && { warehouseId: opts.warehouseId }),
      ...(user.warehouseId && user.role !== "company_admin" && user.role !== "super_admin"
        ? { warehouseId: user.warehouseId }
        : {}),
    });

    const [total, rows] = await Promise.all([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true, marketplace: true, marketplaceOrderId: true, status: true,
          items: true, warehouseId: true, assignedOperatorId: true, stationId: true,
          awb: true, courier: true, createdAt: true, updatedAt: true,
        },
      }),
    ]);
    return { rows, meta: { page, limit, total } };
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: {
        recording: { select: { id: true, status: true, startedAt: true, stoppedAt: true, segmentCount: true } },
        evidence: { select: { id: true, status: true, frameCount: true } },
        claims: { select: { id: true, status: true, reason: true } },
      },
    });
    if (!row) throw new NotFoundException("Order not found");
    return row;
  }

  async create(
    user: AuthUser,
    dto: {
      marketplace?: string;
      marketplaceOrderId?: string;
      warehouseId?: string;
      items: Array<{ sku: string; qty: number; name?: string }>;
    },
  ) {
    if (!dto.items?.length) throw new BadRequestException("items required");

    const items = dto.items.map((i) => ({
      sku: i.sku,
      qty: i.qty,
      name: i.name || i.sku,
      scannedQty: 0,
      status: "pending",
    }));

    const created = await this.prisma.order.create({
      data: {
        companyId: user.companyId,
        marketplace: (dto.marketplace as any) || "manual",
        marketplaceOrderId: dto.marketplaceOrderId,
        warehouseId: dto.warehouseId || user.warehouseId,
        items: items as any,
        status: "synced",
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "order.create",
        entityType: "Order",
        entityId: created.id,
        afterState: { marketplaceOrderId: created.marketplaceOrderId, itemCount: items.length },
      },
    });

    return created;
  }

  async assign(user: AuthUser, id: string, dto: { operatorId: string; stationId?: string }) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!order) throw new NotFoundException("Order not found");
    if (!["synced", "queued"].includes(order.status)) {
      throw new BadRequestException(`Cannot assign order in status ${order.status}`);
    }

    const operator = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, { id: dto.operatorId, status: "active" }),
    });
    if (!operator) throw new BadRequestException("Operator not found or inactive");

    return this.prisma.order.update({
      where: { id },
      data: {
        assignedOperatorId: dto.operatorId,
        stationId: dto.stationId,
        status: "queued",
      },
    });
  }

  async dispatch(user: AuthUser, id: string, dto: { awb: string; courier: string }) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!order) throw new NotFoundException("Order not found");
    if (!["scanned", "evidence_ready"].includes(order.status)) {
      throw new BadRequestException(`Cannot dispatch order in status ${order.status}`);
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        awb: dto.awb,
        courier: dto.courier,
        status: "dispatched",
        dispatchedAt: new Date(),
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "order.dispatch",
        entityType: "Order",
        entityId: id,
        afterState: { awb: dto.awb, courier: dto.courier },
      },
    });

    return updated;
  }

  async transition(user: AuthUser, id: string, status: string) {
    const { NotFoundException, BadRequestException } = await import("@nestjs/common");
    const order = await this.prisma.order.findFirst({
      where: { id, companyId: user.companyId },
    });
    if (!order) throw new NotFoundException("Order not found");

    const allowed: Record<string, string[]> = {
      synced: ["queued", "packing", "closed"],
      queued: ["packing", "closed"],
      packing: ["recording", "scanned", "closed"],
      recording: ["scanned", "evidence_ready", "closed"],
      scanned: ["evidence_ready", "dispatched", "closed"],
      evidence_ready: ["dispatched", "closed"],
      dispatched: ["shipped", "claimed", "returned", "closed"],
      shipped: ["claimed", "returned", "closed"],
      claimed: ["closed"],
      returned: ["closed"],
      closed: [],
    };
    if (!(allowed[order.status] || []).includes(status)) {
      throw new BadRequestException(`Invalid status transition: ${order.status} → ${status}`);
    }

    const updated = await this.prisma.order.update({
      where: { id },
      data: { status: status as any },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "order.transition",
        entityType: "Order",
        entityId: id,
        beforeState: { status: order.status },
        afterState: { status },
      },
    });
    return updated;
  }
}