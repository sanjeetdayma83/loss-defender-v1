import {
  Controller, Get, Post, Body, Req, Headers, RawBodyRequest,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsIn } from "class-validator";
import { Request } from "express";
import { BillingService } from "./billing.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";
import { RequirePermission } from "../common/decorators/permissions.decorator";
import { Public } from "../common/decorators/public.decorator";

class SubscribeBody {
  @IsIn(["starter", "professional", "enterprise"])
  plan!: "starter" | "professional" | "enterprise";
  @IsString() @IsNotEmpty() razorpaySubId!: string;
}

@ApiTags("billing")
@Controller("billing")
export class BillingController {
  constructor(private readonly billingService: BillingService) {}

  @Get("plans")
  @Public()
  async plans() {
    return { success: true, data: this.billingService.getPlans(), error: null };
  }

  @Get("subscription")
  @ApiBearerAuth()
  @Roles("company_admin", "super_admin")
  async subscription(@CurrentUser() user: AuthUser) {
    const data = await this.billingService.getSubscription(user);
    return { success: true, data, error: null };
  }

  @Post("subscribe")
  @ApiBearerAuth()
  @RequirePermission("billing.manage")
  @Roles("company_admin", "super_admin")
  async subscribe(@CurrentUser() user: AuthUser, @Body() body: SubscribeBody) {
    const data = await this.billingService.subscribe(user, body);
    return { success: true, data, error: null };
  }

  @Public()
  @Post("webhooks/razorpay")
  async razorpayWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers("x-razorpay-signature") signature?: string,
  ) {
    const raw = req.rawBody;
    if (!raw) {
      return { success: false, error: "rawBody missing" };
    }
    const data = await this.billingService.handleRazorpayWebhook(raw, signature);
    return { success: true, data, error: null };
  }
}