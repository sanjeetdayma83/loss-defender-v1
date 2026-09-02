import { Injectable, UnauthorizedException, ForbiddenException, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { verifyToken } from "@clerk/backend";
import { PrismaService } from "../prisma/prisma.service";

/**
 * Optional helper: verify Clerk JWT and return linked User.
 * Blueprint: no password; no silent tenant create (403 if not linked).
 * Primary path remains ClerkAuthGuard + GET /auth/sync.
 */
@Injectable()
export class ClerkSyncService {
  private readonly logger = new Logger(ClerkSyncService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async resolveUserFromClerkToken(clerkJwt: string) {
    const secretKey = this.config.get<string>("CLERK_SECRET_KEY");
    if (!secretKey || secretKey.includes("PLACE")) {
      throw new UnauthorizedException("Clerk is not configured");
    }

    let payload: Record<string, unknown>;
    try {
      payload = (await verifyToken(clerkJwt, { secretKey })) as Record<string, unknown>;
    } catch (e: any) {
      this.logger.warn(`Clerk verify failed: ${e?.message}`);
      throw new UnauthorizedException("Invalid Clerk session");
    }

    const clerkId = String(payload.sub || "");
    if (!clerkId) throw new UnauthorizedException("Invalid Clerk payload");

    const user = await this.prisma.user.findFirst({
      where: { clerkId },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        companyId: true,
        warehouseId: true,
        status: true,
        clerkId: true,
      },
    });

    if (!user) {
      // Blueprint: invite must link clerkId first — no auto company
      throw new ForbiddenException(
        "No linked account. Accept an invite or contact your admin.",
      );
    }

    if (user.status === "suspended" || user.status === "deleted") {
      throw new UnauthorizedException("Account disabled");
    }

    return user;
  }
}
