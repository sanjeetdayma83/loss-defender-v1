import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class CompaniesService {
  constructor(private readonly prisma: PrismaService) {}

  async me(user: AuthUser) {
    const company = await this.prisma.company.findFirst({
      where: { id: user.companyId },
      select: {
        id: true,
        companyName: true,
        email: true,
        phone: true,
        gst: true,
        pan: true,
        plan: true,
        storageUsed: true,
        storageQuota: true,
        status: true,
        timezone: true,
        currency: true,
        createdAt: true,
      },
    });
    if (!company) throw new NotFoundException("Company not found");
    return {
      ...company,
      storageUsed: company.storageUsed?.toString(),
      storageQuota: company.storageQuota?.toString(),
    };
  }
}