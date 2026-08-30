import { Controller, Post, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty } from "class-validator";
import { ScannerService } from "./scanner.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class ValidateScanDto {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsString() @IsNotEmpty() barcode!: string;
}

@ApiTags("scanner")
@ApiBearerAuth()
@Controller("scanner")
export class ScannerController {
  constructor(private readonly scannerService: ScannerService) {}

  @Post("validate")
  @Roles("company_admin", "warehouse_manager", "supervisor", "packing_operator", "super_admin")
  async validate(@CurrentUser() user: AuthUser, @Body() dto: ValidateScanDto) {
    const data = await this.scannerService.validate(user, dto);
    return { success: true, data, error: null };
  }
}