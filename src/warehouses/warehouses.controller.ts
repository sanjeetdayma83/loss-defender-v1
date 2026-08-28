import {
  Controller, Get, Post, Patch, Body, Param, HttpCode, HttpStatus,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsOptional, IsObject, IsIn, MaxLength,
} from "class-validator";
import { WarehousesService } from "./warehouses.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class CreateWarehouseBody {
  @IsString() @IsNotEmpty() @MaxLength(200) name!: string;
  @IsString() @IsNotEmpty() @MaxLength(50) code!: string;
  @IsObject() address!: Record<string, unknown>;
  @IsString() @IsNotEmpty() city!: string;
  @IsString() @IsNotEmpty() state!: string;
  @IsOptional() @IsString() country?: string;
  @IsString() @IsNotEmpty() timezone!: string;
}

class UpdateWarehouseBody {
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsString() @MaxLength(50) code?: string;
  @IsOptional() @IsObject() address?: Record<string, unknown>;
  @IsOptional() @IsString() city?: string;
  @IsOptional() @IsString() state?: string;
  @IsOptional() @IsString() country?: string;
  @IsOptional() @IsString() timezone?: string;
  @IsOptional() @IsIn(["active", "suspended", "deleted"]) status?: "active" | "suspended" | "deleted";
}

class CreateStationBody {
  @IsString() @IsNotEmpty() @MaxLength(200) stationName!: string;
  @IsString() @IsNotEmpty() @MaxLength(50) stationCode!: string;
  @IsOptional() @IsObject() cameraConfig?: Record<string, unknown>;
  @IsOptional() @IsObject() scannerConfig?: Record<string, unknown>;
  @IsOptional() @IsObject() printerConfig?: Record<string, unknown>;
}

class UpdateStationBody {
  @IsOptional() @IsString() @MaxLength(200) stationName?: string;
  @IsOptional() @IsString() @MaxLength(50) stationCode?: string;
  @IsOptional() @IsObject() cameraConfig?: Record<string, unknown>;
  @IsOptional() @IsObject() scannerConfig?: Record<string, unknown>;
  @IsOptional() @IsObject() printerConfig?: Record<string, unknown>;
  @IsOptional() @IsIn(["online", "offline", "maintenance", "inactive"])
  status?: "online" | "offline" | "maintenance" | "inactive";
}

@ApiTags("warehouses")
@ApiBearerAuth()
@Controller("warehouses")
export class WarehousesController {
  constructor(private readonly warehousesService: WarehousesService) {}

  @Get()
  @ApiOperation({ summary: "List warehouses for current company" })
  async list(@CurrentUser() user: AuthUser) {
    const data = await this.warehousesService.list(user);
    return { success: true, data, error: null };
  }

  @Get(":id")
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.warehousesService.getOne(user, id);
    return { success: true, data, error: null };
  }

  @Post()
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async create(@CurrentUser() user: AuthUser, @Body() body: CreateWarehouseBody) {
    const data = await this.warehousesService.create(user, body);
    return { success: true, data, error: null };
  }

  @Patch(":id")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async update(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: UpdateWarehouseBody,
  ) {
    const data = await this.warehousesService.update(user, id, body);
    return { success: true, data, error: null };
  }

  @Get(":id/stations")
  async listStations(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.warehousesService.listStations(user, id);
    return { success: true, data, error: null };
  }

  @Post(":id/stations")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async createStation(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: CreateStationBody,
  ) {
    const data = await this.warehousesService.createStation(user, id, body);
    return { success: true, data, error: null };
  }

  @Patch(":id/stations/:stationId")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async updateStation(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Param("stationId") stationId: string,
    @Body() body: UpdateStationBody,
  ) {
    const data = await this.warehousesService.updateStation(user, id, stationId, body);
    return { success: true, data, error: null };
  }

  @Post(":id/stations/:stationId/heartbeat")
  @HttpCode(HttpStatus.OK)
  async heartbeat(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Param("stationId") stationId: string,
  ) {
    const data = await this.warehousesService.heartbeat(user, id, stationId);
    return { success: true, data, error: null };
  }
}