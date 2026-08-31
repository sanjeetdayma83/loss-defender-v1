import { Controller, Get, Post, Patch, Param, Body, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsArray, ValidateNested, IsNumber, Min, IsIn } from "class-validator";
import { Type } from "class-transformer";
import { OrdersService } from "./orders.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class OrderItemDto {
  @IsString() @IsNotEmpty() sku!: string;
  @IsNumber() @Min(1) qty!: number;
  @IsOptional() @IsString() name?: string;
}
class CreateOrderDto {
  @IsOptional() @IsString() marketplace?: string;
  @IsOptional() @IsString() marketplaceOrderId?: string;
  @IsOptional() @IsString() warehouseId?: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => OrderItemDto)
  items!: OrderItemDto[];
}
class AssignDto {
  @IsString() @IsNotEmpty() operatorId!: string;
  @IsOptional() @IsString() stationId?: string;
}
class DispatchDto {
  @IsString() @IsNotEmpty() awb!: string;
  @IsString() @IsNotEmpty() courier!: string;
}
class TransitionDto {
  @IsIn([
    "queued", "packing", "recording", "scanned", "evidence_ready",
    "dispatched", "shipped", "claimed", "returned", "closed",
  ])
  status!: string;
}

@ApiTags("orders")
@ApiBearerAuth()
@Controller("orders")
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get()
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "claims_executive", "viewer", "super_admin")
  async list(
    @CurrentUser() user: AuthUser,
    @Query("status") status?: string,
    @Query("warehouseId") warehouseId?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.ordersService.list(user, {
      status, warehouseId,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }

  @Get(":id")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "claims_executive", "viewer", "super_admin")
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.ordersService.get(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    const data = await this.ordersService.create(user, dto);
    return { success: true, data, error: null };
  }

  @Post(":id/assign")
  @Roles("company_admin", "warehouse_manager", "supervisor", "super_admin")
  async assign(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: AssignDto) {
    const data = await this.ordersService.assign(user, id, dto);
    return { success: true, data, error: null };
  }

  @Patch(":id/status")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async transition(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: TransitionDto) {
    const data = await this.ordersService.transition(user, id, dto.status);
    return { success: true, data, error: null };
  }

  @Post(":id/dispatch")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async dispatch(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: DispatchDto) {
    const data = await this.ordersService.dispatch(user, id, dto);
    return { success: true, data, error: null };
  }
}