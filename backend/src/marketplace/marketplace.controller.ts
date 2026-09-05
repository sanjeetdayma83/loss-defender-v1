import {
  Controller, Get, Post, Body, Param, Req, Headers, UnauthorizedException,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsIn } from "class-validator";
import { Request } from "express";
import { MarketplaceService } from "./marketplace.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";
import { RequirePermission } from "../common/decorators/permissions.decorator";
import { Public } from "../common/decorators/public.decorator";

class ConnectBody {
  @IsIn(["amazon", "flipkart", "meesho", "shopify", "woocommerce"])
  marketplace!: "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce";
  @IsString() @IsNotEmpty() accessToken!: string;
  @IsOptional() @IsString() refreshToken?: string;
  @IsOptional() @IsString() webhookSecret?: string;
}

@ApiTags("marketplace")
@ApiBearerAuth()
@Controller("marketplace")
export class MarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async list(@CurrentUser() user: AuthUser) {
    const data = await this.marketplaceService.list(user);
    return { success: true, data, error: null };
  }

  @Get("accounts")
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async accounts(@CurrentUser() user: AuthUser) {
    const data = await this.marketplaceService.list(user);
    return { success: true, data, error: null };
  }

  @Post("connect")
  @RequirePermission("marketplace.connect")
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async connect(@CurrentUser() user: AuthUser, @Body() body: ConnectBody) {
    const data = await this.marketplaceService.connect(user, body);
    return { success: true, data, error: null };
  }

  /** Public webhook — signature verified against raw body bytes (doc §12 #3) */
  @Public()
  @Post("webhooks/:provider")
  async webhook(
    @Param("provider") provider: string,
    @Req() req: Request & { rawBody?: Buffer },
    @Headers("x-marketplace-signature") signature: string | undefined,
  ) {
    const raw = req.rawBody;
    if (!raw || !Buffer.isBuffer(raw)) {
      throw new UnauthorizedException("Raw body required for webhook verification");
    }
    const data = await this.marketplaceService.handleWebhook(
      provider,
      raw,
      signature,
    );
    return { success: true, data, error: null };
  }
}