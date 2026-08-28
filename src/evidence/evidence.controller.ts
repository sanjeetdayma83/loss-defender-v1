import { Controller, Get, Param } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { EvidenceService } from "./evidence.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

@ApiTags("evidence")
@ApiBearerAuth()
@Controller("evidence")
export class EvidenceController {
  constructor(private readonly evidenceService: EvidenceService) {}

  @Get(":id")
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.evidenceService.getOne(user, id);
    return { success: true, data, error: null };
  }

  @Get(":id/download")
  @Roles(
    "company_admin",
    "warehouse_manager",
    "claims_executive",
    "supervisor",
    "super_admin",
  )
  async download(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.evidenceService.getDownloadUrls(user, id);
    return { success: true, data, error: null };
  }
}