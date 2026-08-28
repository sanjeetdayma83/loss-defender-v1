import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { UploadService } from "../upload/upload.service";
import { createHash } from "crypto";

@Injectable()
export class EvidenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly uploadService: UploadService,
  ) {}

  /**
   * MVP: placeholder frames derived from segment metadata.
   * Real FFmpeg extraction is a later worker job — structure is ready.
   */
  async createFromRecording(user: AuthUser, recordingId: string) {
    const rec = await this.prisma.recording.findFirst({
      where: tenantWhere(user.companyId, { id: recordingId }),
      include: { segments: { orderBy: { sequence: "asc" } } },
    });
    if (!rec) throw new NotFoundException("Recording not found");

    const existing = await this.prisma.evidence.findUnique({
      where: { recordingId },
    });
    if (existing) return existing;

    const frames = rec.segments.map((s, i) => ({
      index: i,
      sequence: s.sequence,
      b2Key: s.b2Key,
      checksum: s.checksum,
      placeholder: true,
      note: "Frame extract pending — FFmpeg worker",
    }));

    const checksum = createHash("sha256")
      .update(frames.map((f) => f.checksum).join("|"))
      .digest("hex");

    return this.prisma.evidence.create({
      data: {
        companyId: user.companyId,
        recordingId,
        status: frames.length ? "ready" : "processing",
        frameCount: frames.length,
        frames,
        checksum,
      },
    });
  }

  async getOne(user: AuthUser, id: string) {
    const ev = await this.prisma.evidence.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!ev) throw new NotFoundException("Evidence not found");
    return ev;
  }

  async getDownloadUrls(user: AuthUser, id: string) {
    const ev = await this.getOne(user, id);
    const frames = (ev.frames as { b2Key?: string; index: number }[]) ?? [];
    const urls = [];
    for (const f of frames) {
      if (!f.b2Key) continue;
      const signed = await this.uploadService.signedDownloadUrl(f.b2Key);
      urls.push({ index: f.index, b2Key: f.b2Key, ...signed });
    }
    return { evidenceId: id, checksum: ev.checksum, frames: urls };
  }
}