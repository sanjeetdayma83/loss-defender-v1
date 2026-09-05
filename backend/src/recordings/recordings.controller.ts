import { Controller, Get, Post, Param, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsInt, Min, IsNumber } from "class-validator";
import { Type } from "class-transformer";
import { RecordingsService } from "./recordings.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class StartRecordingDto {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsOptional() @IsString() stationId?: string;
}

class SegmentDto {
  @Type(() => Number) @IsInt() @Min(0) sequence!: number;
  @IsString() @IsNotEmpty() b2Key!: string;
  @IsString() @IsNotEmpty() checksum!: string;
  @Type(() => Number) @IsNumber() @Min(0) sizeBytes!: number;
}

@ApiTags("recordings")
@ApiBearerAuth()
@Controller("recordings")
export class RecordingsController {
  constructor(private readonly recordingsService: RecordingsService) {}

  @Post("start")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async start(@CurrentUser() user: AuthUser, @Body() dto: StartRecordingDto) {
    const data = await this.recordingsService.start(user, dto);
    return { success: true, data, error: null };
  }

  @Post(":id/segments")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async addSegment(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() dto: SegmentDto,
  ) {
    const data = await this.recordingsService.addSegment(user, id, dto);
    return { success: true, data, error: null };
  }

  @Post(":id/pause")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async pause(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.pause(user, id);
    return { success: true, data, error: null };
  }

  @Post(":id/resume")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async resume(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.resume(user, id);
    return { success: true, data, error: null };
  }

  @Post(":id/stop")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async stop(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.stop(user, id);
    return { success: true, data, error: null };
  }

  @Get(":id")
  @Roles(
    "company_admin", "warehouse_manager", "supervisor", "packing_operator",
    "qc_operator", "claims_executive", "viewer", "super_admin",
  )
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.get(user, id);
    return { success: true, data, error: null };
  }
}