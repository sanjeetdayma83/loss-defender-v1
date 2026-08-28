import { Controller, Get, Post, Patch, Body, Param, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsOptional, IsIn, IsObject, MaxLength,
} from "class-validator";
import { ClaimsService } from "./claims.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class CreateClaimBody {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsString() @IsNotEmpty() @MaxLength(200) reason!: string;
  @IsIn(["amazon", "flipkart", "meesho", "shopify", "woocommerce", "manual"])
  marketplace!: "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce" | "manual";
  @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @IsOptional() @IsObject() attachments?: Record<string, unknown>;
}

class TransitionBody {
  @IsIn([
    "under_review", "investigating", "approved", "rejected", "escalated", "closed",
  ])
  status!: string;
}

class DecideBody {
  @IsIn(["approved", "rejected", "escalated"])
  decision!: "approved" | "rejected" | "escalated";
  @IsOptional() @IsString() @MaxLength(2000) note?: string;
}

@ApiTags("claims")
@ApiBearerAuth()
@Controller("claims")
export class ClaimsController {
  constructor(private readonly claimsService: ClaimsService) {}

  @Get()
  @ApiOperation({ summary: "List claims for current company" })
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
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.claimsService.getOne(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles(
    "company_admin",
    "claims_executive",
    "warehouse_manager",
    "super_admin",
  )
  async create(@CurrentUser() user: AuthUser, @Body() body: CreateClaimBody) {
    const data = await this.claimsService.create(user, body);
    return { success: true, data, error: null };
  }

  @Patch(":id/status")
  @Roles("company_admin", "claims_executive", "super_admin")
  async transition(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: TransitionBody,
  ) {
    const data = await this.claimsService.transition(user, id, body.status);
    return { success: true, data, error: null };
  }

  @Post(":id/decide")
  @Roles("company_admin", "claims_executive", "super_admin")
  @ApiOperation({ summary: "Approve / reject / escalate claim" })
  async decide(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: DecideBody,
  ) {
    const data = await this.claimsService.decide(user, id, body);
    return { success: true, data, error: null };
  }
}