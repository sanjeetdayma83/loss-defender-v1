import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";

/** Fail-closed: if metadata present and role cannot satisfy, deny. */
export const PERMISSIONS_KEY = "permissions";

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    // No permission metadata → allow (RolesGuard may still apply)
    if (!required || required.length === 0) return true;

    const request = context.switchToHttp().getRequest();
    const user = request.user;
    if (!user?.role) {
      throw new ForbiddenException("Permission cannot be determined");
    }

    // Super admin bypasses fine-grained checks
    if (user.role === "super_admin") return true;

    // Map roles to broad permission sets (expand as needed)
    const rolePerms: Record<string, string[]> = {
      company_admin: ["*"],
      warehouse_manager: [
        "orders.read", "orders.assign", "scanner.use", "recordings.create",
        "recordings.review", "evidence.read", "analytics.read",
      ],
      supervisor: [
        "orders.read", "scanner.use", "recordings.create", "recordings.review",
        "evidence.read", "analytics.read",
      ],
      packing_operator: [
        "orders.read", "scanner.use", "recordings.create", "evidence.read",
      ],
      qc_operator: ["recordings.review", "evidence.read"],
      claims_executive: [
        "orders.read", "evidence.read", "evidence.download", "claims.decide",
        "returns.decide", "analytics.read",
      ],
      marketplace_manager: ["marketplace.connect", "orders.read"],
      viewer: ["orders.read", "evidence.read", "analytics.read"],
      auditor: ["audit.read"],
    };

    const granted = rolePerms[user.role] || [];
    if (granted.includes("*")) return true;

    const ok = required.every((p) => granted.includes(p));
    if (!ok) {
      throw new ForbiddenException("Insufficient permission");
    }
    return true;
  }
}
