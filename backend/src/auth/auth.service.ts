import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  Logger,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { createHash, randomBytes } from "crypto";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async acceptInvite(inviteToken: string, clerkId: string, email: string) {
    const tokenHash = createHash("sha256").update(inviteToken).digest("hex");
    const invite = await this.prisma.inviteToken.findUnique({ where: { tokenHash } });

    if (!invite || invite.usedAt || invite.expiresAt < new Date()) {
      throw new BadRequestException("Invalid or expired invite token");
    }

    const user = await this.prisma.user.findUnique({ where: { id: invite.userId } });
    if (!user) throw new NotFoundException("Invited user not found");
    if (user.email.toLowerCase() !== email.toLowerCase()) {
      throw new ForbiddenException("Email does not match invite");
    }
    if (user.clerkId) throw new BadRequestException("Invite already accepted");

    const linked = await this.prisma.user.findUnique({ where: { clerkId } });
    if (linked) throw new BadRequestException("Clerk user already linked");

    const [updated] = await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: { clerkId, status: "active", lastLoginAt: new Date() },
        select: {
          id: true, companyId: true, role: true, warehouseId: true, email: true, name: true,
        },
      }),
      this.prisma.inviteToken.update({
        where: { id: invite.id },
        data: { usedAt: new Date() },
      }),
    ]);
    return updated;
  }

  /**
   * First-owner self-serve. Clerk JWT already verified in controller.
   * No silent tenant on bare signup without this call.
   */
  async registerCompany(
    clerkId: string,
    emailFromToken: string | undefined,
    dto: { companyName: string; ownerName: string; email: string; phone: string },
  ) {
    const existing = await this.prisma.user.findUnique({ where: { clerkId } });
    if (existing) {
      throw new BadRequestException("Clerk user already linked to a company");
    }

    const email = (dto.email || emailFromToken || "").toLowerCase().trim();
    if (!email) throw new BadRequestException("email required");
    if (!dto.companyName?.trim()) throw new BadRequestException("companyName required");

    const emailTaken = await this.prisma.user.findUnique({ where: { email } });
    if (emailTaken) throw new BadRequestException("Email already registered");

    return this.prisma.$transaction(async (tx) => {
      const company = await tx.company.create({
        data: {
          companyName: dto.companyName.trim(),
          email,
          phone: dto.phone || "",
          plan: "free",
          status: "active",
        },
      });

      const warehouse = await tx.warehouse.create({
        data: {
          companyId: company.id,
          name: "Main Warehouse",
          code: "MAIN",
          address: {},
          city: "N/A",
          state: "N/A",
          country: "India",
          timezone: "Asia/Kolkata",
          status: "active",
        },
      });

      const user = await tx.user.create({
        data: {
          clerkId,
          companyId: company.id,
          email,
          name: dto.ownerName?.trim() || email.split("@")[0],
          phone: dto.phone || "",
          role: "company_admin",
          status: "active",
          warehouseId: warehouse.id,
          lastLoginAt: new Date(),
        },
        select: {
          id: true,
          companyId: true,
          role: true,
          warehouseId: true,
          email: true,
          name: true,
          clerkId: true,
        },
      });

      this.logger.log(`register-company company=${company.id} user=${user.id}`);
      return { company: { id: company.id, companyName: company.companyName }, warehouse: { id: warehouse.id }, user };
    });
  }

  async handleClerkWebhook(evt: { type?: string; data?: any }) {
    const type = evt?.type;
    const data = evt?.data;
    if (!type || !data) return { ok: true, skipped: true };

    if (type === "user.deleted") {
      const clerkId = data.id as string;
      if (clerkId) {
        await this.prisma.user.updateMany({
          where: { clerkId },
          data: { status: "deleted", clerkId: null },
        });
      }
      return { ok: true, action: "user.deleted" };
    }

    if (type === "user.updated") {
      const clerkId = data.id as string;
      const email = data.email_addresses?.[0]?.email_address as string | undefined;
      if (clerkId && email) {
        await this.prisma.user.updateMany({
          where: { clerkId },
          data: { email: email.toLowerCase() },
        });
      }
      return { ok: true, action: "user.updated" };
    }

    return { ok: true, ignored: type };
  }

  async sync(user: AuthUser) {
    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });
    return {
      id: user.id,
      companyId: user.companyId,
      role: user.role,
      warehouseId: user.warehouseId ?? null,
      email: user.email,
    };
  }

  async logout(user: AuthUser, clerkSessionId?: string) {
    if (clerkSessionId) {
      await this.prisma.session.updateMany({
        where: { userId: user.id, clerkSessionId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
    return { success: true };
  }

  async listSessions(user: AuthUser) {
    return this.prisma.session.findMany({
      where: { userId: user.id, revokedAt: null },
      orderBy: { createdAt: "desc" },
      select: {
        id: true, clerkSessionId: true, ipAddress: true, userAgent: true, createdAt: true,
      },
    });
  }

  async revokeSession(user: AuthUser, sessionId: string) {
    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, userId: user.id },
    });
    if (!session) throw new NotFoundException("Session not found");
    await this.prisma.session.update({
      where: { id: sessionId },
      data: { revokedAt: new Date() },
    });
    return { success: true };
  }

  async createInviteToken(userId: string, expiresInHours = 72): Promise<string> {
    const raw = randomBytes(32).toString("hex");
    const tokenHash = createHash("sha256").update(raw).digest("hex");
    const expiresAt = new Date(Date.now() + expiresInHours * 60 * 60 * 1000);
    await this.prisma.inviteToken.create({ data: { userId, tokenHash, expiresAt } });
    this.logger.log(`[INVITE] userId=${userId} token created (deliver via email in prod)`);
    return raw;
  }
}