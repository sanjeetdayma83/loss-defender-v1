import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

export type CreateReturnDto = {
  orderId: string;
  unboxingRecordingId?: string;
  condition?: string;
};

export type DecideReturnDto = {
  decision: "accepted" | "rejected" | "partial";
  condition?: string;
};

@Injectable()
export class ReturnsService {
  constructor(private readonly prisma: PrismaService) {}

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

  async getOne(user: AuthUser, id: string) {
    const row = await this.prisma.return.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!row) throw new NotFoundException("Return not found");
    return row;
  }

  async create(user: AuthUser, dto: CreateReturnDto) {
    const order = await this.prisma.order.findFirst({
      where: tenantWhere(user.companyId, { id: dto.orderId }),
    });
    if (!order) throw new NotFoundException("Order not found");

    if (dto.unboxingRecordingId) {
      const rec = await this.prisma.recording.findFirst({
        where: tenantWhere(user.companyId, { id: dto.unboxingRecordingId }),
      });
      if (!rec) throw new BadRequestException("unboxingRecordingId not found");
    }

    const row = await this.prisma.return.create({
      data: {
        companyId: user.companyId,
        orderId: dto.orderId,
        unboxingRecordingId: dto.unboxingRecordingId,
        condition: dto.condition,
      },
    });

    if (["dispatched", "shipped", "claimed"].includes(order.status)) {
      await this.prisma.order.update({
        where: { id: order.id },
        data: { status: "returned" },
      });
    }

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "return.create",
        entityType: "Return",
        entityId: row.id,
        afterState: { orderId: dto.orderId },
      },
    });

    return row;
  }

  async decide(user: AuthUser, id: string, dto: DecideReturnDto) {
    const row = await this.prisma.return.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!row) throw new NotFoundException("Return not found");
    if (row.decision) {
      throw new BadRequestException("Return already decided");
    }

    const updated = await this.prisma.return.update({
      where: { id },
      data: {
        decision: dto.decision,
        condition: dto.condition ?? row.condition,
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

    return updated;
  }
}