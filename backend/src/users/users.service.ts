import {
  Injectable, NotFoundException, BadRequestException, ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { AuthService } from "../auth/auth.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly authService: AuthService,
  ) {}

  async list(user: AuthUser, opts: { status?: string; role?: string; page?: number; limit?: number } = {}) {
    const page = Math.max(1, opts.page ?? 1);
    const limit = Math.min(100, Math.max(1, opts.limit ?? 20));
    const where = tenantWhere(user.companyId, {
      ...(opts.status && { status: opts.status as any }),
      ...(opts.role && { role: opts.role as any }),
    });

    const [total, rows] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.user.findMany({
        where,
        orderBy: { createdAt: "desc" },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true, name: true, email: true, phone: true, role: true,
          status: true, warehouseId: true, employeeId: true, lastLoginAt: true, createdAt: true,
        },
      }),
    ]);
    return { rows, meta: { page, limit, total } };
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, { id }),
      select: {
        id: true, name: true, email: true, phone: true, role: true,
        status: true, warehouseId: true, employeeId: true, stationId: true,
        profilePhoto: true, joiningDate: true, lastLoginAt: true, createdAt: true,
      },
    });
    if (!row) throw new NotFoundException("User not found");
    return row;
  }

  async invite(
    user: AuthUser,
    dto: { name: string; email: string; role: string; phone?: string; warehouseId?: string; employeeId?: string },
  ) {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email.toLowerCase() } });
    if (existing) throw new BadRequestException("Email already registered");

    if (dto.warehouseId) {
      const wh = await this.prisma.warehouse.findFirst({
        where: tenantWhere(user.companyId, { id: dto.warehouseId }),
      });
      if (!wh) throw new BadRequestException("Warehouse not found in your company");
    }

    const created = await this.prisma.user.create({
      data: {
        companyId: user.companyId,
        name: dto.name,
        email: dto.email.toLowerCase(),
        phone: dto.phone,
        role: dto.role as any,
        warehouseId: dto.warehouseId,
        employeeId: dto.employeeId,
        status: "pending",
      },
      select: {
        id: true, name: true, email: true, role: true, status: true, warehouseId: true,
      },
    });

    const inviteToken = await this.authService.createInviteToken(created.id);

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "user.invite",
        entityType: "User",
        entityId: created.id,
        afterState: { email: created.email, role: created.role },
      },
    });

    return { user: created, inviteToken };
  }

  async update(
    user: AuthUser,
    id: string,
    dto: { name?: string; phone?: string; role?: string; warehouseId?: string | null; status?: string },
  ) {
    const target = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!target) throw new NotFoundException("User not found");

    if (target.id === user.id && dto.role && dto.role !== target.role) {
      throw new ForbiddenException("Cannot change your own role");
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.role !== undefined && { role: dto.role as any }),
        ...(dto.warehouseId !== undefined && { warehouseId: dto.warehouseId }),
        ...(dto.status !== undefined && { status: dto.status as any }),
      },
      select: {
        id: true, name: true, email: true, role: true, status: true, warehouseId: true,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "user.update",
        entityType: "User",
        entityId: id,
        beforeState: { role: target.role, status: target.status },
        afterState: { role: updated.role, status: updated.status },
      },
    });

    return updated;
  }

  async softDelete(user: AuthUser, id: string) {
    if (id === user.id) {
      throw new ForbiddenException("Cannot delete your own account");
    }
    const target = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!target) throw new NotFoundException("User not found");
    if (target.status === "deleted") {
      return { id, status: "deleted", alreadyDeleted: true };
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: { status: "deleted" },
      select: { id: true, email: true, status: true, role: true },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "user.soft_delete",
        entityType: "User",
        entityId: id,
        beforeState: { status: target.status, role: target.role },
        afterState: { status: "deleted" },
      },
    });

    return updated;
  }
}
}
