import {
  Controller, Get, Post, Delete, Body, Param, Req, HttpCode, HttpStatus,
  UnauthorizedException, Logger,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import { ConfigService } from "@nestjs/config";
import { verifyToken } from "@clerk/backend";
import { AuthService } from "./auth.service";
import { Public } from "../common/decorators/public.decorator";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { IsString, IsNotEmpty, IsEmail } from "class-validator";
import { Request } from "express";

class AcceptInviteDto {
  @IsString() @IsNotEmpty() inviteToken!: string;
  @IsString() @IsNotEmpty() clerkId!: string;
  @IsEmail() email!: string;
}

class RegisterCompanyDto {
  @IsString() @IsNotEmpty() companyName!: string;
  @IsString() @IsNotEmpty() ownerName!: string;
  @IsEmail() email!: string;
  @IsString() phone!: string;
}

@ApiTags("auth")
@Controller("auth")
export class AuthController {
  private readonly logger = new Logger(AuthController.name);

  constructor(
    private readonly authService: AuthService,
    private readonly config: ConfigService,
  ) {}

  @Public()
  @Post("accept-invite")
  @ApiOperation({ summary: "Link Clerk identity to invited User row" })
  async acceptInvite(@Body() dto: AcceptInviteDto) {
    const data = await this.authService.acceptInvite(dto.inviteToken, dto.clerkId, dto.email);
    return { success: true, data, error: null };
  }

  @Public()
  @Post("register-company")
  @ApiOperation({ summary: "First-time company + owner (Clerk JWT required, no prior link)" })
  async registerCompany(@Req() req: Request, @Body() dto: RegisterCompanyDto) {
    const authHeader = req.headers["authorization"];
    if (!authHeader?.startsWith("Bearer ")) {
      throw new UnauthorizedException("Bearer Clerk JWT required");
    }
    const token = authHeader.slice(7);
    const secretKey =
      this.config.get<string>("clerk.secretKey") ||
      this.config.get<string>("CLERK_SECRET_KEY");
    if (!secretKey) throw new UnauthorizedException("Clerk not configured");

    let payload: { sub?: string; email?: string };
    try {
      payload = await verifyToken(token, { secretKey, clockSkewInMs: 120_000 }) as any;
    } catch (e: any) {
      this.logger.warn(`register-company verify failed: ${e?.message}`);
      throw new UnauthorizedException("Invalid Clerk session");
    }

    const clerkId = payload.sub;
    if (!clerkId) throw new UnauthorizedException("Invalid token subject");

    const data = await this.authService.registerCompany(
      clerkId,
      payload.email,
      dto,
    );
    return { success: true, data, error: null };
  }

  @Public()
  @Post("webhooks/clerk")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Clerk lifecycle webhook (Svix)" })
  async clerkWebhook(@Req() req: any) {
    const secret =
      this.config.get<string>("clerk.webhookSigningSecret") ||
      this.config.get<string>("CLERK_WEBHOOK_SIGNING_SECRET");

    let event: any = req.body;
    if (secret && !String(secret).includes("PLACE") && !String(secret).includes("xxx")) {
      const { Webhook } = await import("svix");
      const wh = new Webhook(secret);
      const raw = req.rawBody ? req.rawBody.toString("utf8") : JSON.stringify(req.body);
      event = wh.verify(raw, {
        "svix-id": req.headers["svix-id"] as string,
        "svix-timestamp": req.headers["svix-timestamp"] as string,
        "svix-signature": req.headers["svix-signature"] as string,
      });
    } else {
      this.logger.warn("Clerk webhook secret missing — accepting body without Svix verify (dev only)");
    }

    const data = await this.authService.handleClerkWebhook(event);
    return { success: true, data };
  }

  @Get("sync")
  @ApiBearerAuth()
  @ApiOperation({ summary: "Bootstrap client with companyId, role, warehouseId" })
  async sync(@CurrentUser() user: AuthUser) {
    const data = await this.authService.sync(user);
    return { success: true, data, error: null };
  }

  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @ApiBearerAuth()
  async logout(@CurrentUser() user: AuthUser, @Body() body: { clerkSessionId?: string }) {
    const data = await this.authService.logout(user, body?.clerkSessionId);
    return { success: true, data, error: null };
  }

  @Get("sessions")
  @ApiBearerAuth()
  async listSessions(@CurrentUser() user: AuthUser) {
    const data = await this.authService.listSessions(user);
    return { success: true, data, error: null };
  }

  @Delete("sessions/:id")
  @ApiBearerAuth()
  async revokeSession(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.authService.revokeSession(user, id);
    return { success: true, data, error: null };
  }
}