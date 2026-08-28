import {
  Controller, Get, Post, Body, Param, Req, Headers, RawBodyRequest,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsIn } from "class-validator";
import { Request } from "express";
import { MarketplaceService } from "./marketplace.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";
import { Public } from "../common/decorators/public.decorator";

class ConnectBody {
  @IsIn(["amazon", "flipkart", "meesho", "shopify", "woocommerce"])
  marketplace!: "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce";
  @IsString() @IsNotEmpty() accessToken!: string;
  @IsOptional() @IsString() refreshToken?: string;
  @IsOptional() @IsString() webhookSecret?: string;
}

@ApiTags("marketplace")
@Controller("marketplace")
export class MarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get()
  @ApiBearerAuth()
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async list(@CurrentUser() user: AuthUser) {
    const data = await this.marketplaceService.list(user);
    return { success: true, data, error: null };
  }

  @Post("connect")
  @ApiBearerAuth()
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async connect(@CurrentUser() user: AuthUser, @Body() body: ConnectBody) {
    const data = await this.marketplaceService.connect(user, body);
    return { success: true, data, error: null };
  }

  /** Public webhook — signature verified against raw body bytes. */
  @Public()
  @Post("webhooks/:provider")
  async webhook(
    @Param("provider") provider: string,
    @Req() req: RawBodyRequest<Request>,
    @Headers("x-signature") sig1?: string,
    @Headers("x-hub-signature-256") sig2?: string,
  ) {
    const raw = req.rawBody;
    if (!raw) {
      return { success: false, data: null, error: "rawBody missing — ensure rawBody:true in NestFactory" };
    }
    const signature = sig1 || sig2;
    const data = await this.marketplaceService.handleWebhook(provider, raw, signature);
    return { success: true, data, error: null };
  }
}