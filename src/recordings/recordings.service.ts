import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { EvidenceService } from "../evidence/evidence.service";

@Injectable()
export class RecordingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly evidenceService: EvidenceService,
  ) {}

  async start(user: AuthUser, orderId: string, stationId?: string) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    if (order.recordingId) {
      throw new BadRequestException("Order already has a recording");
    }

    const scannable = ["packing", "recording", "scanned", "queued"];
    if (!scannable.includes(order.status)) {
      throw new BadRequestException(`Cannot start recording in status '${order.status}'`);
    }

    const prefix = `${user.companyId}/recordings/${orderId}`;

    const recording = await this.prisma.recording.create({
      data: {
        companyId: user.companyId,
        operatorId: user.id,
        stationId: stationId ?? order.stationId,
        status: "started",
        b2KeyPrefix: prefix,
      },
    });

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        recordingId: recording.id,
        status: order.status === "queued" || order.status === "packing" ? "recording" : order.status,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "recording.start",
        entityType: "Recording",
        entityId: recording.id,
        afterState: { orderId, stationId },
      },
    });

    return recording;
  }

  async pause(user: AuthUser, id: string) {
    const rec = await this.findOwned(user, id);
    if (rec.status !== "started") {
      throw new BadRequestException(`Cannot pause from status '${rec.status}'`);
    }
    return this.prisma.recording.update({
      where: { id },
      data: { status: "paused" },
    });
  }

  async resume(user: AuthUser, id: string) {
    const rec = await this.findOwned(user, id);
    if (rec.status !== "paused") {
      throw new BadRequestException(`Cannot resume from status '${rec.status}'`);
    }
    return this.prisma.recording.update({
      where: { id },
      data: { status: "started" },
    });
  }

  async registerSegment(
    user: AuthUser,
    id: string,
    dto: { sequence: number; b2Key: string; checksum: string; sizeBytes: number },
  ) {
    const rec = await this.findOwned(user, id);
    if (!["started", "paused"].includes(rec.status)) {
      throw new BadRequestException("Recording is not accepting segments");
    }

    const segment = await this.prisma.recordingSegment.create({
      data: {
        recordingId: id,
        sequence: dto.sequence,
        b2Key: dto.b2Key,
        checksum: dto.checksum,
        sizeBytes: BigInt(dto.sizeBytes),
        uploadedAt: new Date(),
      },
    });

    await this.prisma.recording.update({
      where: { id },
      data: { segmentCount: { increment: 1 } },
    });

    return {
      id: segment.id,
      sequence: segment.sequence,
      b2Key: segment.b2Key,
      checksum: segment.checksum,
      sizeBytes: dto.sizeBytes,
    };
  }

  async stop(user: AuthUser, id: string) {
    const rec = await this.findOwned(user, id);
    if (!["started", "paused"].includes(rec.status)) {
      throw new BadRequestException(`Cannot stop from status '${rec.status}'`);
    }

    const updated = await this.prisma.recording.update({
      where: { id },
      data: { status: "completed", stoppedAt: new Date() },
    });

    // Trigger evidence generation (placeholder frames for MVP; real FFmpeg later)
    const evidence = await this.evidenceService.createFromRecording(user, id);

    // Link evidence to order if present
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { recordingId: id }),
    });
    if (order) {
      await this.prisma.order.update({
        where: { id: order.id },
        data: {
          evidenceId: evidence.id,
          status: order.status === "recording" || order.status === "scanned"
            ? "evidence_ready"
            : order.status,
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
        afterState: { evidenceId: evidence.id, segmentCount: updated.segmentCount },
      },
    });

    return { recording: updated, evidence };
  }

  async getOne(user: AuthUser, id: string) {
    const rec = await this.prisma.recording.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: {
        segments: { orderBy: { sequence: "asc" } },
      },
    });
    if (!rec) throw new NotFoundException("Recording not found");
    return {
      ...rec,
      segments: rec.segments.map((s) => ({
        ...s,
        sizeBytes: s.sizeBytes.toString(),
      })),
    };
  }

  private async findOwned(user: AuthUser, id: string) {
    const rec = await this.prisma.recording.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!rec) throw new NotFoundException("Recording not found");

    const managers = ["company_admin", "warehouse_manager", "supervisor", "super_admin"];
    if (!managers.includes(user.role) && rec.operatorId !== user.id) {
      throw new ForbiddenException("Not your recording");
    }
    return rec;
  }
}