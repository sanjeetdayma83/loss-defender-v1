import {
  Injectable, NotFoundException, BadRequestException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { NotificationsService } from "../notifications/notifications.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class ReturnsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async list(
    user: AuthUser,
    opts: { page?: number; limit?: number } = {},
  ) {
    const page = Math.max(1, opts.page ?? 1);
    const limit = Math.min(100, Math.max(1, opts.limit ?? 20));
    const where = tenantWhere(user.companyId);

    const [total, rows] = await Promise.all([
      this.prisma.return.count({ where }),
      this.prisma.return.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return { rows, meta: { page, limit, total } };
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.return.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!row) throw new NotFoundException("Return not found");
    return row;
  }

  async create(
    user: AuthUser,
    dto: { orderId: string; condition?: string; unboxingRecordingId?: string },
  ) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: dto.orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    const ret = await this.prisma.return.create({
      data: {
        companyId: user.companyId,
        orderId: dto.orderId,
        condition: dto.condition,
        unboxingRecordingId: dto.unboxingRecordingId,
      },
    });

    await this.prisma.order.update({
      where: { id: dto.orderId },
      data: { status: "returned" },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "return.create",
        entityType: "Return",
        entityId: ret.id,
        afterState: { orderId: dto.orderId },
      },
    });

    return ret;
  }

  async decide(
    user: AuthUser,
    id: string,
    dto: { decision: string },
  ) {
    const existing = await this.prisma.return.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!existing) throw new NotFoundException("Return not found");
    if (existing.decision) throw new BadRequestException("Already decided");

    const updated = await this.prisma.return.update({
      where: { id },
      data: {
        decision: dto.decision,
        decidedAt: new Date(),
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "return.decide",
        entityType: "Return",
        entityId: id,
        afterState: { decision: dto.decision },
      },
    });

    await this.notifications.enqueue(user.companyId, "in_app", {
      type: "return.decided",
      returnId: id,
      decision: dto.decision,
    }, user.id);

    return updated;
  }
  }
