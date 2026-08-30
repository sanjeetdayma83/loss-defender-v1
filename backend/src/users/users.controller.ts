import { Controller, Get, Post, Patch, Param, Body, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { IsString, IsNotEmpty, IsEmail, IsOptional, IsIn } from "class-validator";
import { UsersService } from "./users.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";
import { Roles } from "../common/decorators/roles.decorator";

class InviteDto {
  @IsString() @IsNotEmpty() name!: string;
  @IsEmail() email!: string;
  @IsString() @IsNotEmpty() role!: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() warehouseId?: string;
  @IsOptional() @IsString() employeeId?: string;
}

class UpdateUserDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() role?: string;
  @IsOptional() warehouseId?: string | null;
  @IsOptional() @IsIn(["pending", "active", "suspended", "deleted"]) status?: string;
}

@ApiTags("users")
@ApiBearerAuth()
@Controller("users")
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async list(
    @CurrentUser() user: AuthUser,
    @Query("status") status?: string,
    @Query("role") role?: string,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.usersService.list(user, {
      status, role,
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }

  @Get(":id")
  @Roles("company_admin", "warehouse_manager", "super_admin")
  async get(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    const data = await this.usersService.get(user, id);
    return { success: true, data, error: null };
  }

  @Post("invite")
  @Roles("company_admin", "super_admin")
  async invite(@CurrentUser() user: AuthUser, @Body() dto: InviteDto) {
    const data = await this.usersService.invite(user, dto);
    return { success: true, data, error: null };
  }

  @Patch(":id")
  @Roles("company_admin", "super_admin")
  async update(@CurrentUser() user: AuthUser, @Param("id") id: string, @Body() dto: UpdateUserDto) {
    const data = await this.usersService.update(user, id, dto);
    return { success: true, data, error: null };
  }
}