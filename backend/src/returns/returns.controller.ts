import { Controller, Get, Post, Patch, Param, Body, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional } from "class-validator";
import { ReturnsService } from "./returns.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class CreateReturnDto {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsOptional() @IsString() condition?: string;
  @IsOptional() @IsString() unboxingRecordingId?: string;
}

class DecideReturnDto {
  @IsString() @IsNotEmpty() decision!: string;
}

@ApiTags("returns")
@ApiBearerAuth()
@Controller("returns")
export class ReturnsController {
  constructor(private readonly returnsService: ReturnsService) {}

  @Get()
  @Roles("company_admin", "claims_executive", "warehouse_manager", "viewer", "super_admin")
  async list(
    @CurrentUser() user: AuthUser,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.returnsService.list(user, {
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }

  @Get(":id")
  @Roles("company_admin", "claims_executive", "warehouse_manager", "viewer", "super_admin")
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.returnsService.get(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles("company_admin", "claims_executive", "super_admin")
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateReturnDto) {
    const data = await this.returnsService.create(user, dto);
    return { success: true, data, error: null };
  }

  @Patch(":id/decide")
  @Roles("company_admin", "claims_executive", "super_admin")
  async decide(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: DecideReturnDto) {
    const data = await this.returnsService.decide(user, id, dto);
    return { success: true, data, error: null };
  }
}