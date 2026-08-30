import { Controller, Get } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { CompaniesService } from "./companies.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

@ApiTags("companies")
@ApiBearerAuth()
@Controller("companies")
export class CompaniesController {
  constructor(private readonly companiesService: CompaniesService) {}

  @Get("me")
  @Roles("company_admin", "warehouse_manager", "supervisor", "super_admin", "viewer")
  async me(@CurrentUser() user: AuthUser) {
    const data = await this.companiesService.me(user);
    return { success: true, data, error: null };
  }
}