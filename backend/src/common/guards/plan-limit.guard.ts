import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { PrismaService } from "../../prisma/prisma.service";

export const PLAN_LIMIT_KEY = "planLimit";

/** Optional: mark routes that create users/warehouses so plan quotas are enforced. */
@Injectable()
export class PlanLimitGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const limitType = this.reflector.getAllAndOverride<"users" | "warehouses" | null>(
      PLAN_LIMIT_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!limitType) return true;

    const request = context.switchToHttp().getRequest();
    const user = request.user;
    if (!user?.companyId) {
      throw new ForbiddenException("Tenant context missing for plan check");
    }

    const company = await this.prisma.company.findUnique({
      where: { id: user.companyId },
      select: { plan: true },
    });
    const plan = company?.plan || "free";

    const quotas: Record<string, { users: number; warehouses: number }> = {
      free: { users: 3, warehouses: 1 },
      starter: { users: 10, warehouses: 2 },
      professional: { users: 50, warehouses: 5 },
      enterprise: { users: 99999, warehouses: 99999 },
    };
    const q = quotas[plan] || quotas.free;

    if (limitType === "users") {
      const count = await this.prisma.user.count({
        where: { companyId: user.companyId, status: { not: "deleted" } },
      });
      if (count >= q.users) {
        throw new ForbiddenException(`Plan limit: max ${q.users} users on ${plan}`);
      }
    }
    if (limitType === "warehouses") {
      const count = await this.prisma.warehouse.count({
        where: { companyId: user.companyId, status: { not: "deleted" } },
      });
      if (count >= q.warehouses) {
        throw new ForbiddenException(`Plan limit: max ${q.warehouses} warehouses on ${plan}`);
      }
    }
    return true;
  }
}
