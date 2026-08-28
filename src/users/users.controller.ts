import { Controller, Get, Post, Patch, Body, Param } from "@nestjs/common";
import { ApiTags, ApiBearerAuth, ApiOperation } from "@nestjs/swagger";
import {
  IsString, IsNotEmpty, IsEmail, IsOptional, IsIn, MaxLength,
} from "class-validator";
import { UsersService } from "./users.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles, AppRole } from "../common/decorators/roles.decorator";

class InviteUserBody {
  @IsString() @IsNotEmpty() @MaxLength(200) name!: string;
  @IsEmail() email!: string;
  @IsOptional() @IsString() @MaxLength(30) phone?: string;
  @IsIn([
    "company_admin",
    "warehouse_manager",
    "supervisor",
    "packing_operator",
    "qc_operator",
    "claims_executive",
    "marketplace_manager",
    "viewer",
    "auditor",
  ])
  role!: AppRole;
  @IsOptional() @IsString() warehouseId?: string;
  @IsOptional() @IsString() employeeId?: string;
}

class UpdateUserBody {
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsString() @MaxLength(30) phone?: string;
  @IsOptional()
  @IsIn([
    "company_admin",
    "warehouse_manager",
    "supervisor",
    "packing_operator",
    "qc_operator",
    "claims_executive",
    "marketplace_manager",
    "viewer",
    "auditor",
  ])
  role?: AppRole;
  @IsOptional() @IsString() warehouseId?: string | null;
  @IsOptional() @IsString() stationId?: string | null;
  @IsOptional() @IsIn(["pending", "active", "suspended", "deleted"])
  status?: "pending" | "active" | "suspended" | "deleted";
  @IsOptional() @IsString() employeeId?: string;
}

@ApiTags("users")
@ApiBearerAuth()
@Controller("users")
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @Roles("company_admin", "warehouse_manager", "super_admin")
  @ApiOperation({ summary: "List users in current company" })
  async list(@CurrentUser() user: AuthUser) {
    const data = await this.usersService.list(user);
    return { success: true, data, error: null };
  }

  @Get(":id")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async getOne(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.usersService.getOne(user, id);
    return { success: true, data, error: null };
  }

  @Post("invite")
  @Roles("company_admin", "super_admin")
  @ApiOperation({ summary: "Invite user — returns one-time inviteToken" })
  async invite(@CurrentUser() user: AuthUser, @Body() body: InviteUserBody) {
    const data = await this.usersService.invite(user, body);
    return { success: true, data, error: null };
  }

  @Patch(":id")
  @Roles("company_admin", "super_admin")
  async update(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Body() body: UpdateUserBody,
  ) {
    const data = await this.usersService.update(user, id, body);
    return { success: true, data, error: null };
  }
}