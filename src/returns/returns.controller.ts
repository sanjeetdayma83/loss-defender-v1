import { Controller, Get, Post, Body, Param, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsOptional, IsIn, MaxLength,
} from "class-validator";
import { ReturnsService } from "./returns.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class CreateReturnBody {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsOptional() @IsString() unboxingRecordingId?: string;
  @IsOptional() @IsString() @MaxLength(500) condition?: string;
}

class DecideReturnBody {
  @IsIn(["accepted", "rejected", "partial"])
  decision!: "accepted" | "rejected" | "partial";
  @IsOptional() @IsString() @MaxLength(500) condition?: string;
}

@ApiTags("returns")
@ApiBearerAuth()
@Controller("returns")
export class ReturnsController {
  constructor(private readonly returnsService: ReturnsService) {}

  @Get()
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
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.returnsService.getOne(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles(
    "company_admin",
    "claims_executive",
    "warehouse_manager",
    "qc_operator",
    "super_admin",
  )
  async create(@CurrentUser() user: AuthUser, @Body() body: CreateReturnBody) {
    const data = await this.returnsService.create(user, body);
    return { success: true, data, error: null };
  }

  @Post(":id/decide")
  @Roles("company_admin", "claims_executive", "super_admin")
  async decide(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: DecideReturnBody,
  ) {
    const data = await this.returnsService.decide(user, id, body);
    return { success: true, data, error: null };
  }
}