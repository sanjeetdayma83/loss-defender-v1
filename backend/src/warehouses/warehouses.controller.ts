import { Controller, Get, Post, Patch, Param, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsObject } from "class-validator";
import { WarehousesService } from "./warehouses.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class CreateWarehouseDto {
  @IsString() @IsNotEmpty() name!: string;
  @IsString() @IsNotEmpty() code!: string;
  @IsObject() address!: object;
  @IsString() @IsNotEmpty() city!: string;
  @IsString() @IsNotEmpty() state!: string;
  @IsOptional() @IsString() country?: string;
  @IsOptional() @IsString() timezone?: string;
}

class UpdateWarehouseDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsObject() address?: object;
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsString() state?: string;
  @IsOptional() @IsString() status?: string;
}

class AddStationDto {
  @IsString() @IsNotEmpty() stationName!: string;
  @IsString() @IsNotEmpty() stationCode!: string;
}

@ApiTags("warehouses")
@ApiBearerAuth()
@Controller("warehouses")
export class WarehousesController {
  constructor(private readonly warehousesService: WarehousesService) {}

  @Get()
  @Roles("company_admin", "warehouse_manager", "supervisor", "super_admin")
  async list(@CurrentUser() user: AuthUser) {
    const data = await this.warehousesService.list(user);
    return { success: true, data, error: null };
  }

  @Get(":id")
  @Roles("company_admin", "warehouse_manager", "supervisor", "super_admin")
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.warehousesService.get(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles("company_admin", "super_admin")
  async create(@CurrentUser() user: AuthUser, @Body() dto: CreateWarehouseDto) {
    const data = await this.warehousesService.create(user, dto);
    return { success: true, data, error: null };
  }

  @Patch(":id")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async update(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: UpdateWarehouseDto) {
    const data = await this.warehousesService.update(user, id, dto);
    return { success: true, data, error: null };
  }

  @Post(":id/stations")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async addStation(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() dto: AddStationDto,
  ) {
    const data = await this.warehousesService.addStation(user, id, dto);
    return { success: true, data, error: null };
  }
}