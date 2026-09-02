import {
  Injectable, NotFoundException, BadRequestException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { StorageService } from "../storage/storage.service";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class UploadService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storage: StorageService,
  ) {}

  async init(
    user: AuthUser,
    dto: { recordingId: string; sequence: number; contentType?: string; sizeBytes?: number },
  ) {
    const recording = await this.prisma.recording.findFirst({
      where: { id: dto.recordingId, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");
    if (recording.status === "completed") {
      throw new BadRequestException("Recording already completed");
    }

    const prefix = recording.b2KeyPrefix || `recordings/${user.companyId}/${recording.id}`;
    const key = `${prefix}/seg-${String(dto.sequence).padStart(4, "0")}.mp4`;
    const contentType = dto.contentType || "video/mp4";

    const signedUrl = await this.storage.getUploadSignedUrl(key, contentType);
    const multipart = await this.storage.createMultipart(key, contentType);

    return {
      key,
      sequence: dto.sequence,
      signedUrl,
      uploadId: multipart.uploadId,
      b2Configured: this.storage.isConfigured(),
      message: this.storage.isConfigured()
        ? "PUT binary to signedUrl, then POST /upload/complete"
        : "B2 not configured — register segment with any key for local/dev",
    };
  }

  async signPart(
    user: AuthUser,
    dto: { recordingId: string; key: string; uploadId: string; partNumber: number },
  ) {
    const recording = await this.prisma.recording.findFirst({
      where: { id: dto.recordingId, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");

    const signedUrl = await this.storage.signPart(dto.key, dto.uploadId, dto.partNumber);
    return { signedUrl, partNumber: dto.partNumber };
  }

  async complete(
    user: AuthUser,
    dto: {
      recordingId: string;
      sequence: number;
      b2Key: string;
      sizeBytes: number;
      checksum: string;
      uploadId?: string;
      parts?: Array<{ ETag: string; PartNumber: number }>;
    },
  ) {
    const recording = await this.prisma.recording.findFirst({
      where: { id: dto.recordingId, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");

    if (dto.uploadId && dto.parts?.length) {
      await this.storage.completeMultipart(dto.b2Key, dto.uploadId, dto.parts);
    }

    const segment = await this.prisma.recordingSegment.upsert({
      where: {
        recordingId_sequence: {
          recordingId: dto.recordingId,
          sequence: dto.sequence,
        },
      },
      create: {
        recordingId: dto.recordingId,
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

    const count = await this.prisma.recordingSegment.count({
      where: { recordingId: dto.recordingId },
    });
    await this.prisma.recording.update({
      where: { id: dto.recordingId },
      data: { segmentCount: count },
    });

    return {
      segmentId: segment.id,
      sequence: segment.sequence,
      b2Key: segment.b2Key,
      segmentCount: count,
    };
  }
}