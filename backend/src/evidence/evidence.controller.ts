import { Controller, Get, Patch, Param, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsNumber, IsOptional, IsString, Min } from "class-validator";
import { EvidenceService } from "./evidence.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class MarkReadyDto {
  @IsNumber() @Min(0) frameCount!: number;
  @IsOptional() frames?: any;
  @IsOptional() @IsString() checksum?: string;
}

@ApiTags("evidence")
@ApiBearerAuth()
@Controller("evidence")
export class EvidenceController {
  constructor(private readonly evidenceService: EvidenceService) {}

  @Get(":id")
  @Roles("company_admin", "warehouse_manager", "supervisor", "qc_operator", "claims_executive", "viewer", "super_admin")
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.evidenceService.get(user, id);
    return { success: true, data, error: null };
  }

  @Patch(":id/ready")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async markReady(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: MarkReadyDto) {
    const data = await this.evidenceService.markReady(user, id, dto);
    return { success: true, data, error: null };
  }
}