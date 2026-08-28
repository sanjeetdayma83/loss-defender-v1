import { Controller, Post, Get, Body, Param } from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import { IsString, IsNotEmpty, MaxLength } from "class-validator";
import { ScannerService } from "./scanner.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class ValidateScanBody {
  @IsString() @IsNotEmpty() orderId!: string;
  @IsString() @IsNotEmpty() @MaxLength(128) barcode!: string;
}

@ApiTags("scanner")
@ApiBearerAuth()
@Controller("scanner")
export class ScannerController {
  constructor(private readonly scannerService: ScannerService) {}

  @Post("validate")
  @Roles(
    "packing_operator",
    "qc_operator",
    "supervisor",
    "warehouse_manager",
    "company_admin",
    "super_admin",
  )
  @ApiOperation({
    summary: "Validate a barcode against an order — real SKU/qty/duplicate logic",
  })
  async validate(@CurrentUser() user: AuthUser, @Body() body: ValidateScanBody) {
    const data = await this.scannerService.validate(user, body.orderId, body.barcode);
    // HTTP 200 even on business rejection — client uses data.result
    return { success: true, data, error: null };
  }

  @Get("progress/:orderId")
  @Roles(
    "packing_operator",
    "qc_operator",
    "supervisor",
    "warehouse_manager",
    "company_admin",
    "super_admin",
  )
  async progress(@CurrentUser() user: AuthUser, @Param("orderId") orderId: string) {
    const data = await this.scannerService.getProgress(user, orderId);
    return { success: true, data, error: null };
  }
}