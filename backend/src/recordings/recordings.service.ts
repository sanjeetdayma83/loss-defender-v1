import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { randomUUID } from "crypto";

@Injectable()
export class RecordingsService {
  constructor(private readonly prisma: PrismaService) {}

  async start(user: AuthUser, dto: { orderId: string; stationId?: string }) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: dto.orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");
    if (order.recordingId) throw new BadRequestException("Recording already exists for this order");
    if (!["queued", "packing", "scanned"].includes(order.status)) {
      throw new BadRequestException(`Cannot start recording in status ${order.status}`);
    }

    const managerRoles = ["company_admin", "warehouse_manager", "supervisor", "super_admin"];
    if (
      !managerRoles.includes(user.role) &&
      order.assignedOperatorId &&
      order.assignedOperatorId !== user.id
    ) {
      throw new ForbiddenException("Order assigned to another operator");
    }

    const recordingId = randomUUID();
    const b2KeyPrefix = `companies/${user.companyId}/recordings/${recordingId}`;

    const [recording] = await this.prisma.$transaction([
      this.prisma.recording.create({
        data: {
          id: recordingId,
          companyId: user.companyId,
          operatorId: user.id,
          stationId: dto.stationId || order.stationId,
          status: "started",
          b2KeyPrefix,
        },
      }),
      this.prisma.order.update({
        where: { id: order.id },
        data: {
          recordingId,
          status: "recording",
          assignedOperatorId: order.assignedOperatorId || user.id,
        },
      }),
    ]);

    return recording;
  }

  async stop(user: AuthUser, id: string) {
    const recording = await this.prisma.recording.findFirst({
      where: { id, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");
    if (recording.status === "completed") throw new BadRequestException("Already stopped");

    const updated = await this.prisma.recording.update({
      where: { id },
      data: { status: "completed", stoppedAt: new Date() },
    });

    // Link evidence placeholder
    const evidence = await this.prisma.evidence.create({
      data: {
        companyId: user.companyId,
        recordingId: id,
        status: "processing",
      },
    });

    await this.prisma.order.updateMany({
      where: { recordingId: id },
      data: { evidenceId: evidence.id, status: "evidence_ready" },
    });

    return { recording: updated, evidenceId: evidence.id };
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.recording.findFirst({
      where: { id, companyId: user.companyId },
      include: {
        segments: { orderBy: { sequence: "asc" } },
        order: { select: { id: true, marketplaceOrderId: true, status: true } },
      },
    });
    if (!row) throw new NotFoundException("Recording not found");
    return row;
  }
}