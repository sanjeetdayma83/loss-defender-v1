import { Controller, Get, Query } from "@nestjs/common";
import { ApiTags, ApiBearerAuth } from "@nestjs/swagger";
import { NotificationsService } from "./notifications.service";
import { CurrentUser, AuthUser } from "../common/decorators/current-user.decorator";

@ApiTags("notifications")
@ApiBearerAuth()
@Controller("notifications")
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  async list(
    @CurrentUser() user: AuthUser,
    @Query("page") page?: string,
    @Query("limit") limit?: string,
  ) {
    const result = await this.notificationsService.list(user, {
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 20,
    });
    return { success: true, data: result.rows, meta: result.meta, error: null };
  }
}
