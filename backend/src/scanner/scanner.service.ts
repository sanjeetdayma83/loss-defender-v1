import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class ScannerService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * REAL barcode validation — never returns hardcoded success.
   * Checks: order exists, barcode matches an item SKU, qty not exceeded, not already fully scanned.
   */
  async validate(user: AuthUser, dto: { orderId: string; barcode: string }) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: dto.orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    if (!["queued", "packing", "recording", "scanned"].includes(order.status)) {
      throw new BadRequestException(`Cannot scan order in status ${order.status}`);
    }

    // Optional: only assigned operator can scan (except managers)
    const managerRoles = ["company_admin", "warehouse_manager", "supervisor", "super_admin"];
    if (
      !managerRoles.includes(user.role) &&
      order.assignedOperatorId &&
      order.assignedOperatorId !== user.id
    ) {
      throw new ForbiddenException("Order assigned to another operator");
    }

    const barcode = (dto.barcode || "").trim();
    if (!barcode) {
      return {
        valid: false,
        code: "EMPTY_BARCODE",
        message: "Barcode is empty",
        haptic: "error",
      };
    }

    const items = (order.items as any[]) || [];
    const itemIndex = items.findIndex(
      (i) => String(i.sku).toLowerCase() === barcode.toLowerCase(),
    );

    if (itemIndex === -1) {
      return {
        valid: false,
        code: "WRONG_SKU",
        message: `SKU "${barcode}" is not on this order`,
        haptic: "error",
        expectedSkus: items.map((i) => i.sku),
      };
    }

    const item = items[itemIndex];
    const scannedQty = Number(item.scannedQty || 0);
    const requiredQty = Number(item.qty || 0);

    if (scannedQty >= requiredQty) {
      return {
        valid: false,
        code: "DUPLICATE",
        message: `SKU "${barcode}" already fully scanned (${scannedQty}/${requiredQty})`,
        haptic: "warning",
        item: { sku: item.sku, scannedQty, requiredQty },
      };
    }

    // Increment scannedQty
    items[itemIndex] = {
      ...item,
      scannedQty: scannedQty + 1,
      status: scannedQty + 1 >= requiredQty ? "complete" : "partial",
    };

    const allComplete = items.every((i) => Number(i.scannedQty || 0) >= Number(i.qty || 0));
    const newStatus = allComplete ? "scanned" : order.status === "queued" ? "packing" : order.status;

    await this.prisma.order.update({
      where: { id: order.id },
      data: {
        items: items as any,
        status: newStatus as any,
      },
    });

    return {
      valid: true,
      code: "OK",
      message: allComplete ? "All items scanned" : `Scanned ${scannedQty + 1}/${requiredQty}`,
      haptic: "success",
      item: {
        sku: item.sku,
        name: item.name,
        scannedQty: scannedQty + 1,
        requiredQty,
      },
      allComplete,
      remaining: items
        .filter((i) => Number(i.scannedQty || 0) < Number(i.qty || 0))
        .map((i) => ({
          sku: i.sku,
          name: i.name,
          remaining: Number(i.qty) - Number(i.scannedQty || 0),
        })),
    };
  }
}