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

export type ValidateScanResult =
  | {
      result: "accepted";
      sku: string;
      scannedQty: number;
      requiredQty: number;
      remaining: number;
      allMatched: boolean;
      items: OrderItem[];
    }
  | {
      result: "rejected";
      reason: "invalid_format" | "wrong_sku" | "duplicate" | "over_qty" | "order_not_scannable";
      message: string;
      items?: OrderItem[];
    };

/**
 * REAL barcode/SKU validation — never a hardcoded success.
 * Security Rule #2 from the blueprint.
 */
@Injectable()
export class ScannerService {
  constructor(private readonly prisma: PrismaService) {}

  async validate(
    user: AuthUser,
    orderId: string,
    barcode: string,
  ): Promise<ValidateScanResult> {
    const raw = (barcode ?? "").trim();

    // 1) Format check
    if (!raw || raw.length < 3 || raw.length > 128) {
      return {
        result: "rejected",
        reason: "invalid_format",
        message: "Barcode format invalid (length 3–128 required)",
      };
    }
    // Allow alphanumeric, hyphen, underscore — reject control chars
    if (!/^[A-Za-z0-9\-_./]+$/.test(raw)) {
      return {
        result: "rejected",
        reason: "invalid_format",
        message: "Barcode contains invalid characters",
      };
    }

    // 2) Load order — tenant scoped
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    // Operator may only scan orders assigned to them (unless manager+)
    const managerRoles = [
      "company_admin",
      "warehouse_manager",
      "supervisor",
      "super_admin",
    ];
    if (
      !managerRoles.includes(user.role) &&
      order.assignedOperatorId &&
      order.assignedOperatorId !== user.id
    ) {
      throw new ForbiddenException("Order is assigned to another operator");
    }

    const scannable = ["packing", "recording", "scanned", "queued"];
    if (!scannable.includes(order.status)) {
      return {
        result: "rejected",
        reason: "order_not_scannable",
        message: `Order status '${order.status}' does not allow scanning`,
      };
    }

    const items = (order.items as OrderItem[]) ?? [];
    if (!items.length) {
      return {
        result: "rejected",
        reason: "wrong_sku",
        message: "Order has no items",
      };
    }

    // 3) Match SKU (case-insensitive)
    const idx = items.findIndex(
      (i) => i.sku.toLowerCase() === raw.toLowerCase(),
    );
    if (idx === -1) {
      return {
        result: "rejected",
        reason: "wrong_sku",
        message: `SKU '${raw}' is not on this order`,
        items,
      };
    }

    const item = items[idx];
    const scanned = item.scannedQty ?? 0;
    const required = item.qty;

    // 4) Duplicate / over-qty
    if (scanned >= required) {
      return {
        result: "rejected",
        reason: scanned === required ? "duplicate" : "over_qty",
        message:
          scanned === required
            ? `SKU '${item.sku}' already fully scanned (${scanned}/${required})`
            : `SKU '${item.sku}' would exceed required qty (${scanned}/${required})`,
        items,
      };
    }

    // 5) Accept — increment
    const nextItems = items.map((it, i) =>
      i === idx
        ? {
            ...it,
            scannedQty: scanned + 1,
            status: scanned + 1 >= required ? "matched" : "partial",
          }
        : it,
    );

    await this.prisma.order.update({
      where: { id: orderId },
      data: { items: nextItems as any },
    });

    const allMatched = nextItems.every(
      (it) => (it.scannedQty ?? 0) >= it.qty,
    );

    // Auto-advance to scanned when all matched
    if (allMatched && order.status !== "scanned" && order.status !== "evidence_ready") {
      const canGoScanned = ["packing", "recording", "queued"].includes(order.status);
      if (canGoScanned) {
        await this.prisma.order.update({
          where: { id: orderId },
          data: { status: "scanned" },
        });
      }
    }

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "scanner.validate",
        entityType: "Order",
        entityId: orderId,
        afterState: {
          sku: item.sku,
          scannedQty: scanned + 1,
          requiredQty: required,
          allMatched,
        },
      },
    });

    return {
      result: "accepted",
      sku: item.sku,
      scannedQty: scanned + 1,
      requiredQty: required,
      remaining: required - (scanned + 1),
      allMatched,
      items: nextItems,
    };
  }

  async getProgress(user: AuthUser, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: orderId }),
      select: { id: true, status: true, items: true },
    });
    if (!order) throw new NotFoundException("Order not found");

    const items = (order.items as OrderItem[]) ?? [];
    const totalRequired = items.reduce((s, i) => s + i.qty, 0);
    const totalScanned = items.reduce((s, i) => s + (i.scannedQty ?? 0), 0);
    const allMatched = items.length > 0 && items.every((i) => (i.scannedQty ?? 0) >= i.qty);

    return {
      orderId: order.id,
      status: order.status,
      totalRequired,
      totalScanned,
      allMatched,
      items,
    };
  }
}