import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
  ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { AuthService } from "../auth/auth.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { AppRole } from "../common/decorators/roles.decorator";

export type InviteUserDto = {
  name: string;
  email: string;
  phone?: string;
  role: AppRole;
  warehouseId?: string;
  employeeId?: string;
};

export type UpdateUserDto = {
  name?: string;
  phone?: string;
  role?: AppRole;
  warehouseId?: string | null;
  stationId?: string | null;
  status?: "pending" | "active" | "suspended" | "deleted";
  employeeId?: string;
};

const ASSIGNABLE_ROLES: AppRole[] = [
  "company_admin",
  "warehouse_manager",
  "supervisor",
  "packing_operator",
  "qc_operator",
  "claims_executive",
  "marketplace_manager",
  "viewer",
  "auditor",
];

@Injectable()
export class UsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly authService: AuthService,
  ) {}

  async list(user: AuthUser) {
    return this.prisma.user.findMany({
      where: tenantWhere(user.companyId, { status: { not: "deleted" } }),
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        employeeId: true,
        warehouseId: true,
        stationId: true,
        lastLoginAt: true,
        createdAt: true,
      },
      orderBy: { createdAt: "desc" },
    });
  }

  async getOne(user: AuthUser, id: string) {
    const row = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, { id }),
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        employeeId: true,
        warehouseId: true,
        stationId: true,
        profilePhoto: true,
        joiningDate: true,
        lastLoginAt: true,
        clerkId: true,
        createdAt: true,
      },
    });
    if (!row) throw new NotFoundException("User not found");
    return row;
  }

  /**
   * Create a pending user + invite token.
   * Clerk owns credentials — we never set a password.
   * Returns inviteToken once (caller should email it).
   */
  async invite(user: AuthUser, dto: InviteUserDto) {
    if (!ASSIGNABLE_ROLES.includes(dto.role)) {
      throw new BadRequestException(`Role '${dto.role}' cannot be assigned`);
    }
    if (dto.role === "super_admin") {
      throw new ForbiddenException("Cannot invite super_admin via this endpoint");
    }

    const email = dto.email.toLowerCase().trim();
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException("A user with this email already exists");
    }

    if (dto.warehouseId) {
      const wh = await this.prisma.warehouse.findFirst({
        where: tenantWhere(user.companyId, { id: dto.warehouseId }),
      });
      if (!wh) throw new BadRequestException("warehouseId not in your company");
    }

    const created = await this.prisma.user.create({
      data: {
        companyId: user.companyId,
        name: dto.name,
        email,
        phone: dto.phone,
        role: dto.role as any,
        warehouseId: dto.warehouseId,
        employeeId: dto.employeeId,
        status: "pending",
      },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        status: true,
        warehouseId: true,
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

    // inviteToken returned once — email delivery is a later notifications concern
    return { user: created, inviteToken };
  }

  async update(user: AuthUser, id: string, dto: UpdateUserDto) {
    const existing = await this.prisma.user.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!existing) throw new NotFoundException("User not found");

    if (dto.role) {
      if (!ASSIGNABLE_ROLES.includes(dto.role)) {
        throw new BadRequestException(`Role '${dto.role}' cannot be assigned`);
      }
      if (dto.role === "super_admin") {
        throw new ForbiddenException("Cannot assign super_admin");
      }
    }

    if (dto.warehouseId) {
      const wh = await this.prisma.warehouse.findFirst({
        where: tenantWhere(user.companyId, { id: dto.warehouseId }),
      });
      if (!wh) throw new BadRequestException("warehouseId not in your company");
    }

    const updated = await this.prisma.user.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.phone !== undefined && { phone: dto.phone }),
        ...(dto.role !== undefined && { role: dto.role as any }),
        ...(dto.warehouseId !== undefined && { warehouseId: dto.warehouseId }),
        ...(dto.stationId !== undefined && { stationId: dto.stationId }),
        ...(dto.status !== undefined && { status: dto.status }),
        ...(dto.employeeId !== undefined && { employeeId: dto.employeeId }),
      },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        status: true,
        warehouseId: true,
        stationId: true,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "user.update",
        entityType: "User",
        entityId: id,
        beforeState: { role: existing.role, status: existing.status },
        afterState: { role: updated.role, status: updated.status },
      },
    });

    return updated;
  }
}