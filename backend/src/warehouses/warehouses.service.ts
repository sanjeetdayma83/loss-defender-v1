import { Injectable, NotFoundException, BadRequestException } from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class WarehousesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser) {
    return this.prisma.warehouse.findMany({
      where: tenantWhere(user.companyId, { status: { not: "deleted" } }),
      orderBy: { createdAt: "desc" },
      include: {
        stations: {
          select: { id: true, stationName: true, stationCode: true, status: true, lastHeartbeatAt: true },
        },
        _count: { select: { users: true, orders: true } },
      },
    });
  }

  async get(user: AuthUser, id: string) {
    const row = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: {
        stations: true,
        _count: { select: { users: true, orders: true } },
      },
    });
    if (!row) throw new NotFoundException("Warehouse not found");
    return row;
  }

  async create(
    user: AuthUser,
    dto: {
      name: string; code: string; address: object; city: string; state: string;
      country?: string; timezone?: string;
    },
  ) {
    const exists = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { code: dto.code }),
    });
    if (exists) throw new BadRequestException("Warehouse code already exists");

    const created = await this.prisma.warehouse.create({
      data: {
        companyId: user.companyId,
        name: dto.name,
        code: dto.code,
        address: dto.address as any,
        city: dto.city,
        state: dto.state,
        country: dto.country || "India",
        timezone: dto.timezone || "Asia/Kolkata",
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "warehouse.create",
        entityType: "Warehouse",
        entityId: created.id,
        afterState: { name: created.name, code: created.code },
      },
    });

    return created;
  }

  async update(
    user: AuthUser,
    id: string,
    dto: { name?: string; address?: object; city?: string; state?: string; status?: string },
  ) {
    const existing = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!existing) throw new NotFoundException("Warehouse not found");

    return this.prisma.warehouse.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.address !== undefined && { address: dto.address as any }),
        ...(dto.city !== undefined && { city: dto.city }),
        ...(dto.state !== undefined && { state: dto.state }),
        ...(dto.status !== undefined && { status: dto.status as any }),
      },
    });
  }

  async addStation(
    user: AuthUser,
    warehouseId: string,
    dto: { stationName: string; stationCode: string },
  ) {
    const wh = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { id: warehouseId }),
    });
    if (!wh) throw new NotFoundException("Warehouse not found");

    return this.prisma.station.create({
      data: {
        warehouseId,
        stationName: dto.stationName,
        stationCode: dto.stationCode,
      },
    });
  }
}