import { Controller, Post, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsInt, Min, Max, IsArray, ValidateNested, IsOptional,
} from "class-validator";
import { Type } from "class-transformer";
import { UploadService } from "./upload.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";

class InitMultipartBody {
  @IsString() @IsNotEmpty() filename!: string;
  @IsString() @IsNotEmpty() contentType!: string;
  @IsOptional() @IsString() prefix?: string;
}

class PresignPartBody {
  @IsString() @IsNotEmpty() key!: string;
  @IsString() @IsNotEmpty() uploadId!: string;
  @IsInt() @Min(1) @Max(10000) partNumber!: number;
}

class PartEtag {
  @IsInt() @Min(1) partNumber!: number;
  @IsString() @IsNotEmpty() etag!: string;
}

class CompleteMultipartBody {
  @IsString() @IsNotEmpty() key!: string;
  @IsString() @IsNotEmpty() uploadId!: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => PartEtag)
  parts!: PartEtag[];
}

class AbortBody {
  @IsString() @IsNotEmpty() key!: string;
  @IsString() @IsNotEmpty() uploadId!: string;
}

@ApiTags("upload")
@ApiBearerAuth()
@Controller("upload")
export class UploadController {
  constructor(private readonly uploadService: UploadService) {}

  @Post("init")
  async init(@CurrentUser() user: AuthUser, @Body() body: InitMultipartBody) {
    const data = await this.uploadService.initMultipart(user, body);
    return { success: true, data, error: null };
  }

  @Post("part")
  async part(@Body() body: PresignPartBody) {
    const data = await this.uploadService.presignPart(body.key, body.uploadId, body.partNumber);
    return { success: true, data, error: null };
  }

  @Post("complete")
  async complete(@Body() body: CompleteMultipartBody) {
    const data = await this.uploadService.completeMultipart(body.key, body.uploadId, body.parts);
    return { success: true, data, error: null };
  }

  @Post("abort")
  async abort(@Body() body: AbortBody) {
    const data = await this.uploadService.abortMultipart(body.key, body.uploadId);
    return { success: true, data, error: null };
  }
}