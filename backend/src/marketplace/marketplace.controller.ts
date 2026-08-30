import { Controller, Get } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { MarketplaceService } from "./marketplace.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

@ApiTags("marketplace")
@ApiBearerAuth()
@Controller("marketplace")
export class MarketplaceController {
  constructor(private readonly marketplaceService: MarketplaceService) {}

  @Get("accounts")
  @Roles("company_admin", "marketplace_manager", "super_admin")
  async listAccounts(@CurrentUser() user: AuthUser) {
    const data = await this.marketplaceService.listAccounts(user);
    return { success: true, data, error: null };
  }
}