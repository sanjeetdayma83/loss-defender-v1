import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { StorageService } from "../storage/storage.service";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class EvidenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.evidence.findFirst({
      where: { id, companyId: user.companyId },
      include: {
        order: {
          select: {
            id: true,
            marketplaceOrderId: true,
            status: true,
            items: true,
            awb: true,
            courier: true,
            recordingId: true,
          },
        },
      },
    });
    if (!row) throw new NotFoundException("Evidence not found");

    const frames = Array.isArray(row.frames) ? (row.frames as any[]) : [];
    const framesWithUrls = await Promise.all(
      frames.map(async (f: any) => {
        if (f?.b2Key) {
          const url = await this.storage.getDownloadSignedUrl(f.b2Key);
          return { ...f, downloadUrl: url };
        }
        return f;
      }),
    );

    let segments: any[] = [];
    if (row.recordingId) {
      const segs = await this.prisma.recordingSegment.findMany({
        where: { recordingId: row.recordingId },
        orderBy: { sequence: "asc" },
      });
      segments = await Promise.all(
        segs.map(async (s) => ({
          id: s.id,
          sequence: s.sequence,
          b2Key: s.b2Key,
          sizeBytes: s.sizeBytes.toString(),
          checksum: s.checksum,
          downloadUrl: await this.storage.getDownloadSignedUrl(s.b2Key),
        })),
      );
    }

    return {
      ...row,
      frames: framesWithUrls,
      segments,
      b2Configured: this.storage.isConfigured(),
    };
  }

  async getByOrder(user: AuthUser, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, companyId: user.companyId },
    });
    if (!order?.evidenceId) throw new NotFoundException("No evidence for this order");
    return this.get(user, order.evidenceId);
  }

  async markReady(
    user: AuthUser,
    id: string,
    dto: { frameCount: number; frames?: any; checksum?: string },
  ) {
    const existing = await this.prisma.evidence.findFirst({
      where: { id, companyId: user.companyId },
    });
    if (!existing) throw new NotFoundException("Evidence not found");

    const updated = await this.prisma.evidence.update({
      where: { id },
      data: {
        status: "ready",
        frameCount: dto.frameCount,
        frames: (dto.frames as any) ?? existing.frames,
        checksum: dto.checksum,
      },
    });

    await this.prisma.order.updateMany({
      where: { evidenceId: id, companyId: user.companyId },
      data: { status: "evidence_ready" },
    });

    return updated;
  }
}