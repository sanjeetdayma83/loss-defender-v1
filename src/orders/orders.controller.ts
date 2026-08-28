import {
  Controller, Get, Post, Patch, Body, Param, Query,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsOptional, IsArray, IsIn, IsInt, Min,
  ValidateNested, MaxLength, ArrayMinSize,
} from "class-validator";
import { Type } from "class-transformer";
import { OrdersService } from "./orders.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class OrderItemBody {
  @IsString() @IsNotEmpty() sku!: string;
  @IsInt() @Min(1) qty!: number;
  @IsOptional() @IsString() name?: string;
}

class CreateOrderBody {
  @IsOptional()
  @IsIn(["amazon", "flipkart", "meesho", "shopify", "woocommerce", "manual"])
  marketplace?: "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce" | "manual";
  @IsOptional() @IsString() marketplaceOrderId?: string;
  @IsOptional() @IsString() warehouseId?: string;
  @IsArray() @ArrayMinSize(1) @ValidateNested({ each: true }) @Type(() => OrderItemBody)
  items!: OrderItemBody[];
}

class AssignOrderBody {
  @IsString() @IsNotEmpty() assignedOperatorId!: string;
  @IsOptional() @IsString() stationId?: string;
}

class TransitionBody {
  @IsIn([
    "queued", "packing", "recording", "scanned", "evidence_ready",
    "dispatched", "shipped", "claimed", "returned", "closed",
  ])
  status!: string;
}

class DispatchBody {
  @IsString() @IsNotEmpty() @MaxLength(100) awb!: string;
  @IsString() @IsNotEmpty() @MaxLength(100) courier!: string;
}

@ApiTags("orders")
@ApiBearerAuth()
@Controller("orders")
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get()
  @ApiOperation({ summary: "List orders (tenant-scoped)" })
  async list(
    @CurrentUser() user: AuthUser,
    @Query("status") status?: string,
    @Query("warehouseId") warehouseId?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.ordersService.list(user, {
      status,
      warehouseId,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }

  @Get(":id")
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.ordersService.getOne(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles("company_admin", "warehouse_manager", "marketplace_manager", "super_admin")
  async create(@CurrentUser() user: AuthUser, @Body() body: CreateOrderBody) {
    const data = await this.ordersService.create(user, body);
    return { success: true, data, error: null };
  }

  @Post(":id/assign")
  @Roles("company_admin", "warehouse_manager", "supervisor", "super_admin")
  async assign(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: AssignOrderBody,
  ) {
    const data = await this.ordersService.assign(user, id, body);
    return { success: true, data, error: null };
  }

  @Patch(":id/status")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async transition(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: TransitionBody,
  ) {
    const data = await this.ordersService.transition(user, id, body.status);
    return { success: true, data, error: null };
  }

  @Post(":id/dispatch")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async dispatch(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: DispatchBody,
  ) {
    const data = await this.ordersService.dispatch(user, id, body);
    return { success: true, data, error: null };
  }
}