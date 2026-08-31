import { Controller, Get, Post, Body } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsOptional, IsIn } from "class-validator";
import { MarketplaceService } from "./marketplace.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

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
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async connect(@CurrentUser() user: AuthUser, @Body() body: ConnectBody) {
    const data = await this.marketplaceService.connect(user, body);
    return { success: true, data, error: null };
  }
}