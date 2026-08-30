import { Controller, Post, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsNumber, IsOptional, Min } from "class-validator";
import { UploadService } from "./upload.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class InitUploadDto {
  @IsString() @IsNotEmpty() recordingId!: string;
  @IsNumber() @Min(0) sequence!: number;
  @IsOptional() @IsString() contentType?: string;
  @IsOptional() @IsNumber() sizeBytes?: number;
}

class CompleteUploadDto {
  @IsString() @IsNotEmpty() recordingId!: string;
  @IsNumber() @Min(0) sequence!: number;
  @IsString() @IsNotEmpty() b2Key!: string;
  @IsNumber() @Min(1) sizeBytes!: number;
  @IsString() @IsNotEmpty() checksum!: string;
}

@ApiTags("upload")
@ApiBearerAuth()
@Controller("upload")
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  @Post("init")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async init(@CurrentUser() user: AuthUser, @Body() dto: InitUploadDto) {
    const data = await this.uploadService.init(user, dto);
    return { success: true, data, error: null };
  }

  @Post("complete")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async complete(@CurrentUser() user: AuthUser, @Body() dto: CompleteUploadDto) {
    const data = await this.uploadService.complete(user, dto);
    return { success: true, data, error: null };
  }
}