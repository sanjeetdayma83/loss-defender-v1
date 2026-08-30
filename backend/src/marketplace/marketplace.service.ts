import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class MarketplaceService {
  constructor(private readonly prisma: PrismaService) {}

  async listAccounts(user: AuthUser) {
    return this.prisma.marketplaceAccount.findMany({
      where: tenantWhere(user.companyId),
      select: {
        id: true,
        marketplace: true,
        status: true,
        lastSyncAt: true,
        createdAt: true,
      },
    });
  }
}