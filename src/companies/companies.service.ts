import { Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

export type UpdateCompanyDto = {
  companyName?: string;
  phone?: string;
  gst?: string;
  pan?: string;
  address?: Record<string, unknown>;
  timezone?: string;
  currency?: string;
  logo?: string;
};

@Injectable()
export class CompaniesService {
  constructor(private readonly prisma: PrismaService) {}

  /** Always scoped to the authenticated user's companyId — never from client input. */
  async getMe(user: AuthUser) {
    const company = await this.prisma.company.findFirst({
      where: tenantWhere(user.companyId),
      select: {
        id: true,
        companyName: true,
        email: true,
        phone: true,
        gst: true,
        pan: true,
        address: true,
        timezone: true,
        currency: true,
        plan: true,
        storageUsed: true,
        storageQuota: true,
        status: true,
        logo: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!company) {
      throw new NotFoundException("Company not found");
    }

    return company;
  }

  async updateMe(user: AuthUser, dto: UpdateCompanyDto) {
    // Only company_admin (and super_admin) should reach here — enforced by @Roles on controller
    const existing = await this.prisma.company.findFirst({
      where: tenantWhere(user.companyId),
    });
    if (!existing) {
      throw new NotFoundException("Company not found");
    }

    const updated = await this.prisma.company.update({
      where: { id: user.companyId },
      data: {
        ...(dto.companyName !== undefined && { companyName: dto.companyName }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.gst !== undefined && { gst: dto.gst }),
        ...(dto.pan !== undefined && { pan: dto.pan }),
        ...(dto.address !== undefined && { address: dto.address }),
        ...(dto.timezone !== undefined && { timezone: dto.timezone }),
        ...(dto.currency !== undefined && { currency: dto.currency }),
        ...(dto.logo !== undefined && { logo: dto.logo }),
      },
      select: {
        id: true,
        companyName: true,
        email: true,
        phone: true,
        gst: true,
        pan: true,
        address: true,
        timezone: true,
        currency: true,
        plan: true,
        storageUsed: true,
        storageQuota: true,
        status: true,
        logo: true,
        updatedAt: true,
      },
    });

    // Audit critical mutation
    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "company.update",
        entityType: "Company",
        entityId: user.companyId,
        beforeState: {
          companyName: existing.companyName,
          phone: existing.phone,
          gst: existing.gst,
          pan: existing.pan,
        },
        afterState: {
          companyName: updated.companyName,
          phone: updated.phone,
          gst: updated.gst,
          pan: updated.pan,
        },
      },
    });

    return updated;
  }
}