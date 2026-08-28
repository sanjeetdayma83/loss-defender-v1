import { Controller, Get, Patch, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import { IsOptional, IsString, IsObject, MaxLength } from "class-validator";
import { CompaniesService } from "./companies.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class UpdateCompanyBody {
  @IsOptional() @IsString() @MaxLength(200) companyName?: string;
  @IsOptional() @IsString() @MaxLength(30) phone?: string;
  @IsOptional() @IsString() @MaxLength(30) gst?: string;
  @IsOptional() @IsString() @MaxLength(20) pan?: string;
  @IsOptional() @IsObject() address?: Record<string, unknown>;
  @IsOptional() @IsString() @MaxLength(64) timezone?: string;
  @IsOptional() @IsString() @MaxLength(8) currency?: string;
  @IsOptional() @IsString() @MaxLength(500) logo?: string;
}

@ApiTags("companies")
@ApiBearerAuth()
@Controller("companies")
export class CompaniesController {
  constructor(private readonly companiesService: CompaniesService) {}

  /**
   * ONLY "me"-scoped. No GET /companies/:id — prevents cross-tenant access (Security Rule #1).
   */
  @Get("me")
  @ApiOperation({ summary: "Get current tenant company profile" })
  async getMe(@CurrentUser() user: AuthUser) {
    const data = await this.companiesService.getMe(user);
    return { success: true, data, error: null };
  }

  @Patch("me")
  @Roles("company_admin", "super_admin")
  @ApiOperation({ summary: "Update current tenant company profile" })
  async updateMe(@CurrentUser() user: AuthUser, @Body() body: UpdateCompanyBody) {
    const data = await this.companiesService.updateMe(user, body);
    return { success: true, data, error: null };
  }
}