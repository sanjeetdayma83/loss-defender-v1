import { Injectable } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser, opts: { page?: number; limit?: number } = {}) {
    const page = Math.max(1, opts.page ?? 1);
    const limit = Math.min(50, Math.max(1, opts.limit ?? 20));
    const where = {
      ...tenantWhere(user.companyId),
      OR: [{ userId: user.id }, { userId: null }],
    };
    const [total, rows] = await Promise.all([
      this.prisma.notification.count({ where }),
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return { rows, meta: { page, limit, total } };
  }

  /** Queue a notification row — actual delivery (email/FCM) is a worker job. */
  async enqueue(
    companyId: string,
    channel: "email" | "push" | "whatsapp" | "in_app",
    payload: Record<string, unknown>,
    userId?: string,
  ) {
    return this.prisma.notification.create({
      data: {
        companyId,
        userId: userId ?? null,
        channel,
        payload: payload as any,
        status: "pending",
      },
    });
  }
}
