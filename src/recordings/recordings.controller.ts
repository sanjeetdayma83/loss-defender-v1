import { Controller, Get, Post, Body, Param } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsOptional, IsInt, Min, MaxLength,
} from "class-validator";
import { RecordingsService } from "./recordings.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class StartBody {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsOptional() @IsString() stationId?: string;
}

class SegmentBody {
  @IsInt() @Min(0) sequence!: number;
  @IsString() @IsNotEmpty() b2Key!: string;
  @IsString() @IsNotEmpty() @MaxLength(128) checksum!: string;
  @IsInt() @Min(1) sizeBytes!: number;
}

@ApiTags("recordings")
@ApiBearerAuth()
@Controller("recordings")
export class RecordingsController {
  constructor(private readonly recordingsService: RecordingsService) {}

  @Post("start")
  @Roles("packing_operator", "supervisor", "warehouse_manager", "company_admin", "super_admin")
  async start(@CurrentUser() user: AuthUser, @Body() body: StartBody) {
    const data = await this.recordingsService.start(user, body.orderId, body.stationId);
    return { success: true, data, error: null };
  }

  @Post(":id/pause")
  @Roles("packing_operator", "supervisor", "warehouse_manager", "company_admin", "super_admin")
  async pause(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.pause(user, id);
    return { success: true, data, error: null };
  }

  @Post(":id/resume")
  @Roles("packing_operator", "supervisor", "warehouse_manager", "company_admin", "super_admin")
  async resume(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.resume(user, id);
    return { success: true, data, error: null };
  }

  @Post(":id/segments")
  @Roles("packing_operator", "supervisor", "warehouse_manager", "company_admin", "super_admin")
  async segment(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: SegmentBody,
  ) {
    const data = await this.recordingsService.registerSegment(user, id, body);
    return { success: true, data, error: null };
  }

  @Post(":id/stop")
  @Roles("packing_operator", "supervisor", "warehouse_manager", "company_admin", "super_admin")
  async stop(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.stop(user, id);
    return { success: true, data, error: null };
  }

  @Get(":id")
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.recordingsService.getOne(user, id);
    return { success: true, data, error: null };
  }
}