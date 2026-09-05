import { Controller, Get, ForbiddenException } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

@ApiTags("admin")
@ApiBearerAuth()
@Controller("admin")
export class AdminController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Platform list — only super_admin AND SUPER_ADMIN_COMPANY_ACCESS=true
   * Doc §12 #5 fail-closed.
   */
  @Get("companies")
  @Roles("super_admin")
  async companies(@CurrentUser() user: AuthUser) {
    const allowed =
      this.config.get<string>("SUPER_ADMIN_COMPANY_ACCESS") === "true" ||
      process.env.SUPER_ADMIN_COMPANY_ACCESS === "true";
    if (!allowed) {
      throw new ForbiddenException(
        "Platform company list disabled (set SUPER_ADMIN_COMPANY_ACCESS=true)",
      );
    }
    const rows = await this.prisma.company.findMany({
      select: {
        id: true,
        companyName: true,
        email: true,
        plan: true,
        status: true,
        storageUsed: true,
        storageQuota: true,
        createdAt: true,
      },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    return {
      success: true,
      data: rows.map((r) => ({
        ...r,
        storageUsed: r.storageUsed.toString(),
        storageQuota: r.storageQuota.toString(),
      })),
      error: null,
    };
  }
}