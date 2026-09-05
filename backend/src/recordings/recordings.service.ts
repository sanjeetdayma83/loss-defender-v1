import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class RecordingsService {
  constructor(private readonly prisma: PrismaService) {}

  async start(user: AuthUser, dto: { orderId: string; stationId?: string }) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: dto.orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    const allowed = ["queued", "packing", "recording", "scanned"];
    if (!allowed.includes(order.status)) {
      throw new BadRequestException(`Cannot start recording for order in status ${order.status}`);
    }

    if (order.recordingId) {
      const existing = await this.prisma.recording.findUnique({ where: { id: order.recordingId } });
      if (existing && existing.status !== "completed" && existing.status !== "failed") {
        return existing;
      }
    }

    const recording = await this.prisma.recording.create({
      data: {
        companyId: user.companyId,
        operatorId: user.id,
        stationId: dto.stationId || order.stationId,
        status: "started",
        b2KeyPrefix: `recordings/${user.companyId}/${order.id}`,
      },
    });

    await this.prisma.order.update({
      where: { id: order.id },
      data: {
        recordingId: recording.id,
        status: "recording",
        assignedOperatorId: order.assignedOperatorId || user.id,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "recording.start",
        entityType: "Recording",
        entityId: recording.id,
        afterState: { orderId: order.id },
      },
    });

    return recording;
  }

  async pause(user: AuthUser, id: string) {
    const recording = await this.prisma.recording.findFirst({
      where: { id, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");
    if (recording.status !== "started") {
      throw new BadRequestException(`Cannot pause recording in status ${recording.status}`);
    }
    return this.prisma.recording.update({
      where: { id },
      data: { status: "paused" },
    });
  }

  async resume(user: AuthUser, id: string) {
    const recording = await this.prisma.recording.findFirst({
      where: { id, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");
    if (recording.status !== "paused") {
      throw new BadRequestException(`Cannot resume recording in status ${recording.status}`);
    }
    return this.prisma.recording.update({
      where: { id },
      data: { status: "started" },
    });
  }

  async stop(user: AuthUser, id: string) {
    const recording = await this.prisma.recording.findFirst({
      where: { id, companyId: user.companyId },
      include: { segments: true, order: true },
    });
    if (!recording) throw new NotFoundException("Recording not found");
    if (recording.status === "completed") {
      return { recording, evidence: null, alreadyStopped: true };
    }

    const updated = await this.prisma.recording.update({
      where: { id },
      data: {
        status: "completed",
        stoppedAt: new Date(),
        segmentCount: recording.segments.length,
      },
    });

    // Create evidence shell (frames filled later by worker / markReady)
    let evidence = await this.prisma.evidence.findFirst({
      where: { recordingId: id },
    });
    if (!evidence) {
      evidence = await this.prisma.evidence.create({
        data: {
          companyId: user.companyId,
          recordingId: id,
          status: "processing",
          frameCount: 0,
          frames: [],
        },
      });
    }

    // Link evidence to order + advance status
    const order = recording.order;
    if (order) {
      await this.prisma.order.update({
        where: { id: order.id },
        data: {
          evidenceId: evidence.id,
          status: "evidence_ready",
        },
      });
    }

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "recording.stop",
        entityType: "Recording",
        entityId: id,
        afterState: {
          segmentCount: updated.segmentCount,
          evidenceId: evidence.id,
        },
      },
    });

    return { recording: updated, evidence, alreadyStopped: false };
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.recording.findFirst({
      where: { id, companyId: user.companyId },
      include: {
        segments: { orderBy: { sequence: "asc" } },
        order: {
          select: {
            id: true, marketplaceOrderId: true, status: true, items: true,
          },
        },
      },
    });
    if (!row) throw new NotFoundException("Recording not found");
    return row;
  }

  async addSegment(
    user: AuthUser,
    recordingId: string,
    dto: { sequence: number; b2Key: string; checksum: string; sizeBytes: number },
  ) {
    const recording = await this.prisma.recording.findFirst({
      where: { id: recordingId, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");
    if (recording.status === "completed" || recording.status === "failed") {
      throw new BadRequestException(`Cannot add segment to ${recording.status} recording`);
    }

    const segment = await this.prisma.recordingSegment.upsert({
      where: {
        recordingId_sequence: {
          recordingId,
          sequence: dto.sequence,
        },
      },
      create: {
        recordingId,
        sequence: dto.sequence,
        b2Key: dto.b2Key,
        checksum: dto.checksum,
        sizeBytes: BigInt(dto.sizeBytes),
        uploadedAt: new Date(),
      },
      update: {
        b2Key: dto.b2Key,
        checksum: dto.checksum,
        sizeBytes: BigInt(dto.sizeBytes),
        uploadedAt: new Date(),
      },
    });

    const count = await this.prisma.recordingSegment.count({ where: { recordingId } });
    await this.prisma.recording.update({
      where: { id: recordingId },
      data: { segmentCount: count },
    });

    return {
      id: segment.id,
      sequence: segment.sequence,
      b2Key: segment.b2Key,
      sizeBytes: segment.sizeBytes.toString(),
      segmentCount: count,
    };
  }
}
