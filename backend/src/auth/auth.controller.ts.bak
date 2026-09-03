import {
  Controller, Get, Post, Delete, Body, Param, Req, HttpCode, HttpStatus,
  UnauthorizedException,
} from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import { AuthService } from "./auth.service";
import { Public } from "../common/decorators/public.decorator";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { IsString, IsNotEmpty, IsEmail, IsOptional, MinLength } from "class-validator";
import { Request } from "express";

class AcceptInviteDto {
  @IsString() @IsNotEmpty() inviteToken!: string;
  @IsString() @IsNotEmpty() clerkId!: string;
  @IsEmail() email!: string;
}

class RegisterCompanyDto {
  @IsString() @MinLength(2) companyName!: string;
  @IsString() @MinLength(2) ownerName!: string;
  @IsEmail() email!: string;
  @IsOptional() @IsString() phone?: string;
}

@ApiTags("auth")
@Controller("auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post("register-company")
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: "Create company + company_admin linked to Clerk JWT" })
  async registerCompany(@Req() req: Request, @Body() dto: RegisterCompanyDto) {
    const auth = req.headers["authorization"];
    if (!auth?.startsWith("Bearer ")) {
      throw new UnauthorizedException("Bearer Clerk session required");
    }
    const data = await this.authService.registerCompany(auth.slice(7), dto);
    return { success: true, data, error: null };
  }

  @Public()
  @Post("accept-invite")
  @ApiOperation({ summary: "Link Clerk identity to invited User row" })
  async acceptInvite(@Body() dto: AcceptInviteDto) {
    const data = await this.authService.acceptInvite(dto.inviteToken, dto.clerkId, dto.email);
    return { success: true, data, error: null };
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
