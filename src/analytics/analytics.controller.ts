import { Controller, Get } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { AnalyticsService } from "./analytics.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

@ApiTags("analytics")
@ApiBearerAuth()
@Controller("analytics")
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get("kpis")
  @Roles(
    "company_admin",
    "warehouse_manager",
    "supervisor",
    "claims_executive",
    "viewer",
    "super_admin",
  )
  async kpis(@CurrentUser() user: AuthUser) {
    const data = await this.analyticsService.kpis(user);
    return { success: true, data, error: null };
  }
}