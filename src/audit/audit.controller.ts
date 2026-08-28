import { Controller, Get, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { AuditService } from "./audit.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

@ApiTags("audit")
@ApiBearerAuth()
@Controller("audit-logs")
export class AuditController {
  constructor(private readonly auditService: AuditService) {}

  @Get()
  @Roles("company_admin", "auditor", "super_admin")
  async list(
    @CurrentUser() user: AuthUser,
    @Query("action") action?: string,
    @Query("entityType") entityType?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.auditService.list(user, {
      action,
      entityType,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 50,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }
}