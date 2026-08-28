import { CanActivate, ExecutionContext, Injectable, ForbiddenException } from "@nestjs/common";

@Injectable()
export class TenantGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user?.companyId) {
      throw new ForbiddenException("Tenant context missing");
    }

    if (request.body && typeof request.body === "object" && "companyId" in request.body) {
      delete request.body.companyId;
    }
    if (request.query && typeof request.query === "object" && "companyId" in request.query) {
      delete request.query.companyId;
    }

    request.companyId = user.companyId;
    return true;
  }
}
