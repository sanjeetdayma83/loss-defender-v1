import { Controller, Get, Post, Patch, Param, Body, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsIn } from "class-validator";
import { ClaimsService } from "./claims.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class CreateClaimDto {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsString() @IsNotEmpty() reason!: string;
  @IsString() @IsNotEmpty() marketplace!: string;
  @IsOptional() @IsString() description?: string;
}

class DecideClaimDto {
  @IsIn(["approved", "rejected"]) decision!: "approved" | "rejected";
  @IsOptional() @IsString() note?: string;
}

@ApiTags("claims")
@ApiBearerAuth()
@Controller("claims")
export class ClaimsController {
  constructor(private readonly claimsService: ClaimsService) {}

  @Get()
  @Roles("company_admin", "claims_executive", "warehouse_manager", "viewer", "super_admin")
  async list(
    @CurrentUser() user: AuthUser,
    @Query("status") status?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.claimsService.list(user, {
      status,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }

  @Get(":id")
  @Roles("company_admin", "claims_executive", "warehouse_manager", "viewer", "super_admin")
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.claimsService.get(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles("company_admin", "claims_executive", "super_admin")
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateClaimDto) {
    const data = await this.claimsService.create(user, dto);
    return { success: true, data, error: null };
  }

  @Patch(":id/decide")
  @Roles("company_admin", "claims_executive", "super_admin")
  async decide(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: DecideClaimDto) {
    const data = await this.claimsService.decide(user, id, dto);
    return { success: true, data, error: null };
  }
}