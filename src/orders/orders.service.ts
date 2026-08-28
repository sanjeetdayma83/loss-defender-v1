import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

type OrderItem = {
  sku: string;
  qty: number;
  name?: string;
  scannedQty?: number;
  status?: string;
};

export type CreateOrderDto = {
  marketplace?: "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce" | "manual";
  marketplaceOrderId?: string;
  warehouseId?: string;
  items: OrderItem[];
  metadata?: Record<string, unknown>;
};

export type AssignOrderDto = {
  assignedOperatorId: string;
  stationId?: string;
};

export type DispatchOrderDto = {
  awb: string;
  courier: string;
};

const ALLOWED_TRANSITIONS: Record<string, string[]> = {
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
    });

    const [total, rows] = await Promise.all([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          marketplace: true,
          marketplaceOrderId: true,
          status: true,
          warehouseId: true,
          assignedOperatorId: true,
          stationId: true,
          awb: true,
          courier: true,
          items: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
    ]);

    return { rows, meta: { page, limit, total } };
  }

  async getOne(user: AuthUser, id: string) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: {
        claims: {
          select: { id: true, status: true, reason: true, createdAt: true },
        },
      },
    });
    if (!order) throw new NotFoundException("Order not found");
    return order;
  }

  async create(user: AuthUser, dto: CreateOrderDto) {
    if (!dto.items?.length) {
      throw new BadRequestException("items array is required and must not be empty");
    }
    for (const item of dto.items) {
      if (!item.sku || !item.qty || item.qty < 1) {
        throw new BadRequestException("Each item needs sku and qty >= 1");
      }
    }

    if (dto.warehouseId) {
      const wh = await this.prisma.warehouse.findFirst({
        where: tenantWhere(user.companyId, { id: dto.warehouseId }),
      });
      if (!wh) throw new BadRequestException("warehouseId not in your company");
    }

    const items = dto.items.map((i) => ({
      sku: i.sku,
      qty: i.qty,
      name: i.name ?? i.sku,
      scannedQty: 0,
      status: "pending",
    }));

    const order = await this.prisma.order.create({
      data: {
        companyId: user.companyId,
        marketplace: (dto.marketplace ?? "manual") as any,
        marketplaceOrderId: dto.marketplaceOrderId,
        warehouseId: dto.warehouseId,
        items,
        metadata: dto.metadata,
        status: "synced",
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "order.create",
        entityType: "Order",
        entityId: order.id,
        afterState: {
          marketplace: order.marketplace,
          marketplaceOrderId: order.marketplaceOrderId,
          itemCount: items.length,
        },
      },
    });

    return order;
  }

  async assign(user: AuthUser, id: string, dto: AssignOrderDto) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!order) throw new NotFoundException("Order not found");

    const operator = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, {
        id: dto.assignedOperatorId,
        status: "active",
      }),
    });
    if (!operator) throw new BadRequestException("Operator not found or not active");

    if (dto.stationId && order.warehouseId) {
      const station = await this.prisma.station.findFirst({
        where: { id: dto.stationId, warehouseId: order.warehouseId },
      });
      if (!station) throw new BadRequestException("Station not in order warehouse");
    }

    const nextStatus =
      order.status === "synced" || order.status === "queued" ? "packing" : order.status;

    this.assertTransition(order.status, nextStatus);

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        assignedOperatorId: dto.assignedOperatorId,
        stationId: dto.stationId,
        status: nextStatus as any,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "order.assign",
        entityType: "Order",
        entityId: id,
        afterState: {
          assignedOperatorId: dto.assignedOperatorId,
          stationId: dto.stationId,
          status: nextStatus,
        },
      },
    });

    return updated;
  }

  async transition(user: AuthUser, id: string, status: string) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!order) throw new NotFoundException("Order not found");

    this.assertTransition(order.status, status);

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

  async dispatch(user: AuthUser, id: string, dto: DispatchOrderDto) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!order) throw new NotFoundException("Order not found");

    this.assertTransition(order.status, "dispatched");

    const updated = await this.prisma.order.update({
      where: { id },
      data: {
        status: "dispatched",
        awb: dto.awb,
        courier: dto.courier,
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

  /** Used by Scanner module — update items JSON with scannedQty. */
  async updateItems(user: AuthUser, id: string, items: OrderItem[]) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!order) throw new NotFoundException("Order not found");

    return this.prisma.order.update({
      where: { id },
      data: { items: items as any },
    });
  }

  private assertTransition(from: string, to: string) {
    const allowed = ALLOWED_TRANSITIONS[from] ?? [];
    if (!allowed.includes(to)) {
      throw new BadRequestException(`Invalid status transition: ${from} → ${to}`);
    }
  }
}