import {
  Injectable, NotFoundException, BadRequestException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { createHash, randomUUID } from "crypto";

@Injectable()
export class UploadService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
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

    const key = `${recording.b2KeyPrefix}/seg-${String(dto.sequence).padStart(4, "0")}.mp4`;
    const uploadId = randomUUID();

    // Placeholder — real B2 multipart init will use @aws-sdk/client-s3 when keys are live
    return {
      uploadId,
      key,
      sequence: dto.sequence,
      // Client will PUT binary to a signed URL (generated when B2 keys configured)
      signedUrl: null,
      message: "Configure B2 keys to receive signed upload URLs",
    };
  }

  async complete(
    user: AuthUser,
    dto: {
      recordingId: string;
      sequence: number;
      b2Key: string;
      sizeBytes: number;
      checksum: string;
    },
  ) {
    const recording = await this.prisma.recording.findFirst({
      where: { id: dto.recordingId, companyId: user.companyId },
    });
    if (!recording) throw new NotFoundException("Recording not found");

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

    await this.prisma.recording.update({
      where: { id: dto.recordingId },
      data: { segmentCount: { increment: 1 } },
    });

    // Update company storage used
    await this.prisma.company.update({
      where: { id: user.companyId },
      data: { storageUsed: { increment: BigInt(dto.sizeBytes) } },
    });

    return {
      id: segment.id,
      sequence: segment.sequence,
      b2Key: segment.b2Key,
      uploadedAt: segment.uploadedAt,
    };
  }
}