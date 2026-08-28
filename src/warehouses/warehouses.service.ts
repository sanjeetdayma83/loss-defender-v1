import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";

export type CreateWarehouseDto = {
  name: string;
  code: string;
  address: Record<string, unknown>;
  city: string;
  state: string;
  country?: string;
  timezone: string;
};

export type UpdateWarehouseDto = Partial<CreateWarehouseDto> & {
  status?: "active" | "suspended" | "deleted";
};

export type CreateStationDto = {
  stationName: string;
  stationCode: string;
  cameraConfig?: Record<string, unknown>;
  scannerConfig?: Record<string, unknown>;
  printerConfig?: Record<string, unknown>;
};

export type UpdateStationDto = Partial<CreateStationDto> & {
  status?: "online" | "offline" | "maintenance" | "inactive";
};

@Injectable()
export class WarehousesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser) {
    return this.prisma.warehouse.findMany({
      where: tenantWhere(user.companyId, { status: { not: "deleted" } }),
      include: {
        stations: {
          select: {
            id: true,
            stationName: true,
            stationCode: true,
            status: true,
            lastHeartbeatAt: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });
  }

  async getOne(user: AuthUser, id: string) {
    const warehouse = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { id }),
      include: { stations: true },
    });
    if (!warehouse) throw new NotFoundException("Warehouse not found");
    return warehouse;
  }

  async create(user: AuthUser, dto: CreateWarehouseDto) {
    const existing = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { code: dto.code }),
    });
    if (existing) {
      throw new ConflictException(`Warehouse code '${dto.code}' already exists`);
    }

    const warehouse = await this.prisma.warehouse.create({
      data: {
        companyId: user.companyId,
        name: dto.name,
        code: dto.code,
        address: dto.address,
        city: dto.city,
        state: dto.state,
        country: dto.country ?? "India",
        timezone: dto.timezone,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "warehouse.create",
        entityType: "Warehouse",
        entityId: warehouse.id,
        afterState: { name: warehouse.name, code: warehouse.code },
      },
    });

    return warehouse;
  }

  async update(user: AuthUser, id: string, dto: UpdateWarehouseDto) {
    const existing = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { id }),
    });
    if (!existing) throw new NotFoundException("Warehouse not found");

    if (dto.code && dto.code !== existing.code) {
      const clash = await this.prisma.warehouse.findFirst({
        where: tenantWhere(user.companyId, { code: dto.code }),
      });
      if (clash) throw new ConflictException(`Warehouse code '${dto.code}' already exists`);
    }

    const updated = await this.prisma.warehouse.update({
      where: { id },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.code !== undefined && { code: dto.code }),
        ...(dto.address !== undefined && { address: dto.address }),
        ...(dto.city !== undefined && { city: dto.city }),
        ...(dto.state !== undefined && { state: dto.state }),
        ...(dto.country !== undefined && { country: dto.country }),
        ...(dto.timezone !== undefined && { timezone: dto.timezone }),
        ...(dto.status !== undefined && { status: dto.status }),
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "warehouse.update",
        entityType: "Warehouse",
        entityId: id,
        beforeState: { name: existing.name, code: existing.code, status: existing.status },
        afterState: { name: updated.name, code: updated.code, status: updated.status },
      },
    });

    return updated;
  }

  // --- Stations (scoped via parent warehouse → company) ---

  async listStations(user: AuthUser, warehouseId: string) {
    await this.assertWarehouseOwned(user, warehouseId);
    return this.prisma.station.findMany({
      where: { warehouseId },
      orderBy: { stationName: "asc" },
    });
  }

  async createStation(user: AuthUser, warehouseId: string, dto: CreateStationDto) {
    await this.assertWarehouseOwned(user, warehouseId);

    const clash = await this.prisma.station.findFirst({
      where: { warehouseId, stationCode: dto.stationCode },
    });
    if (clash) {
      throw new ConflictException(`Station code '${dto.stationCode}' already exists in this warehouse`);
    }

    const station = await this.prisma.station.create({
      data: {
        warehouseId,
        stationName: dto.stationName,
        stationCode: dto.stationCode,
        cameraConfig: dto.cameraConfig,
        scannerConfig: dto.scannerConfig,
        printerConfig: dto.printerConfig,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "station.create",
        entityType: "Station",
        entityId: station.id,
        afterState: { stationName: station.stationName, stationCode: station.stationCode, warehouseId },
      },
    });

    return station;
  }

  async updateStation(
    user: AuthUser,
    warehouseId: string,
    stationId: string,
    dto: UpdateStationDto,
  ) {
    await this.assertWarehouseOwned(user, warehouseId);

    const existing = await this.prisma.station.findFirst({
      where: { id: stationId, warehouseId },
    });
    if (!existing) throw new NotFoundException("Station not found");

    if (dto.stationCode && dto.stationCode !== existing.stationCode) {
      const clash = await this.prisma.station.findFirst({
        where: { warehouseId, stationCode: dto.stationCode },
      });
      if (clash) throw new ConflictException(`Station code '${dto.stationCode}' already exists`);
    }

    return this.prisma.station.update({
      where: { id: stationId },
      data: {
        ...(dto.stationName !== undefined && { stationName: dto.stationName }),
        ...(dto.stationCode !== undefined && { stationCode: dto.stationCode }),
        ...(dto.cameraConfig !== undefined && { cameraConfig: dto.cameraConfig }),
        ...(dto.scannerConfig !== undefined && { scannerConfig: dto.scannerConfig }),
        ...(dto.printerConfig !== undefined && { printerConfig: dto.printerConfig }),
        ...(dto.status !== undefined && { status: dto.status }),
      },
    });
  }

  async heartbeat(user: AuthUser, warehouseId: string, stationId: string) {
    await this.assertWarehouseOwned(user, warehouseId);
    const station = await this.prisma.station.findFirst({
      where: { id: stationId, warehouseId },
    });
    if (!station) throw new NotFoundException("Station not found");

    return this.prisma.station.update({
      where: { id: stationId },
      data: { lastHeartbeatAt: new Date(), status: "online" },
      select: { id: true, status: true, lastHeartbeatAt: true },
    });
  }

  private async assertWarehouseOwned(user: AuthUser, warehouseId: string) {
    const wh = await this.prisma.warehouse.findFirst({
      where: tenantWhere(user.companyId, { id: warehouseId }),
    });
    if (!wh) throw new ForbiddenException("Warehouse not found or not in your company");
  }
}