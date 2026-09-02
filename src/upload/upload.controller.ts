import { Controller, Post, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsInt, Min, IsOptional, IsArray, ValidateNested } from "class-validator";
import { Type } from "class-transformer";
import { UploadService } from "./upload.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class InitUploadDto {
  @IsString() @IsNotEmpty() recordingId!: string;
  @IsInt() @Min(1) sequence!: number;
  @IsOptional() @IsString() contentType?: string;
  @IsOptional() @IsInt() @Min(1) sizeBytes?: number;
}

class SignPartDto {
  @IsString() @IsNotEmpty() recordingId!: string;
  @IsString() @IsNotEmpty() key!: string;
  @IsString() @IsNotEmpty() uploadId!: string;
  @IsInt() @Min(1) partNumber!: number;
}

class PartDto {
  @IsString() @IsNotEmpty() ETag!: string;
  @IsInt() @Min(1) PartNumber!: number;
}

class CompleteUploadDto {
  @IsString() @IsNotEmpty() recordingId!: string;
  @IsInt() @Min(1) sequence!: number;
  @IsString() @IsNotEmpty() b2Key!: string;
  @IsInt() @Min(1) sizeBytes!: number;
  @IsString() @IsNotEmpty() checksum!: string;
  @IsOptional() @IsString() uploadId?: string;
  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => PartDto)
  parts?: PartDto[];
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

  @Post("sign-part")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async signPart(@CurrentUser() user: AuthUser, @Body() dto: SignPartDto) {
    const data = await this.uploadService.signPart(user, dto);
    return { success: true, data, error: null };
  }

  @Post("complete")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async complete(@CurrentUser() user: AuthUser, @Body() dto: CompleteUploadDto) {
    const data = await this.uploadService.complete(user, dto);
    return { success: true, data, error: null };
  }
}