import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class EvidenceService {
  constructor(private readonly prisma: PrismaService) {}

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.evidence.findFirst({
      where: { id, companyId: user.companyId },
      include: {
        order: {
          select: {
            id: true, marketplaceOrderId: true, status: true, items: true, awb: true,
          },
        },
      },
    });
    if (!row) throw new NotFoundException("Evidence not found");
    return row;
  }

  async markReady(user: AuthUser, id: string, dto: { frameCount: number; frames?: any; checksum?: string }) {
    const existing = await this.prisma.evidence.findFirst({
      where: { id, companyId: user.companyId },
    });
    if (!existing) throw new NotFoundException("Evidence not found");

    return this.prisma.evidence.update({
      where: { id },
      data: {
        status: "ready",
        frameCount: dto.frameCount,
        frames: dto.frames as any,
        checksum: dto.checksum,
      },
    });
  }
}