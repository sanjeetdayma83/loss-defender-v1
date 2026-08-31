import { Injectable, BadRequestException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class MarketplaceService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser) {
    return this.listAccounts(user);
  }

  async listAccounts(user: AuthUser) {
    return this.prisma.marketplaceAccount.findMany({
      where: { companyId: user.companyId },
      select: {
        id: true,
        marketplace: true,
        status: true,
        lastSyncAt: true,
        createdAt: true,
      },
    });
  }

  async connect(
    user: AuthUser,
    dto: {
      marketplace: string;
      accessToken: string;
      refreshToken?: string;
      webhookSecret?: string;
    },
  ) {
    if (dto.marketplace === "manual") {
      throw new BadRequestException("Cannot connect manual marketplace");
    }
    const row = await this.prisma.marketplaceAccount.upsert({
      where: {
        companyId_marketplace: {
          companyId: user.companyId,
          marketplace: dto.marketplace as any,
        },
      },
      create: {
        companyId: user.companyId,
        marketplace: dto.marketplace as any,
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        webhookSecret: dto.webhookSecret,
        status: "active",
      },
      update: {
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        webhookSecret: dto.webhookSecret,
        status: "active",
      },
      select: { id: true, marketplace: true, status: true, createdAt: true },
    });
    return row;
  }
}