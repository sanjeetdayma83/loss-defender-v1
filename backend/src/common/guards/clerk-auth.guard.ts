import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
  ForbiddenException,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { verifyToken } from "@clerk/backend";
import { PrismaService } from "../../prisma/prisma.service";
import { IS_PUBLIC_KEY } from "../decorators/public.decorator";

@Injectable()
export class ClerkAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers["authorization"];
    if (!authHeader?.startsWith("Bearer ")) {
      throw new UnauthorizedException("Missing or invalid Authorization header");
    }

    const token = authHeader.slice(7);
    let payload: { sub?: string };

    try {
      payload = await verifyToken(token, {
        secretKey: this.config.get<string>("clerk.secretKey"),
        authorizedParties: this.config.get<string[]>("clerk.authorizedParties"),
      });
    } catch {
      throw new UnauthorizedException("Invalid or expired session token");
    }

    const clerkId = payload.sub;
    if (!clerkId) {
      throw new UnauthorizedException("Token missing subject");
    }

    const user = await this.prisma.user.findUnique({
      where: { clerkId },
      select: {
        id: true,
        companyId: true,
        role: true,
        warehouseId: true,
        clerkId: true,
        email: true,
        status: true,
      },
    });

    if (!user) {
      throw new ForbiddenException(
        "No linked account. Accept an invite or contact your company admin.",
      );
    }
    if (user.status !== "active") {
      throw new ForbiddenException("Account is not active");
    }

    request.user = {
      id: user.id,
      companyId: user.companyId,
      role: user.role,
      warehouseId: user.warehouseId,
      clerkId: user.clerkId!,
      email: user.email,
    };
    return true;
  }
}
