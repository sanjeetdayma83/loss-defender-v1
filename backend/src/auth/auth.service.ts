import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
  UnauthorizedException,
  ConflictException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { verifyToken } from "@clerk/backend";
import { PrismaService } from "../prisma/prisma.service";
import { createHash, randomBytes } from "crypto";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { Role, UserStatus, Status, Plan } from "@prisma/client";

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private async verifyClerkJwt(clerkJwt: string) {
    const secretKey =
      this.config.get<string>("clerk.secretKey") ||
      this.config.get<string>("CLERK_SECRET_KEY");
    if (!secretKey || secretKey.includes("PLACE")) {
      throw new UnauthorizedException("Clerk is not configured");
    }
    try {
      return await verifyToken(clerkJwt, {
        secretKey,
        clockSkewInMs: 120_000,
      });
    } catch (e: any) {
      throw new UnauthorizedException(
        `Invalid Clerk session (${e?.reason || e?.message || "verify failed"})`,
      );
    }
  }

  /**
   * Self-serve: first owner creates company + links clerkId.
   * clerkId ALWAYS from verified JWT sub — never trust client-only id.
   */
  async registerCompany(
    clerkJwt: string,
    dto: { companyName: string; ownerName: string; email: string; phone?: string },
  ) {
    const payload: any = await this.verifyClerkJwt(clerkJwt);
    const clerkId = String(payload.sub || "");
    if (!clerkId) throw new UnauthorizedException("Token missing subject");

    const email = (dto.email || "").trim().toLowerCase();
    if (!email) throw new BadRequestException("email required");

    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ clerkId }, { email }] },
    });
    if (existing?.clerkId === clerkId) {
      return {
        companyId: existing.companyId,
        userId: existing.id,
        role: existing.role,
        email: existing.email,
        alreadyRegistered: true,
      };
    }
    if (existing && existing.email === email && existing.clerkId && existing.clerkId !== clerkId) {
      throw new ConflictException("Email already linked to another Clerk user");
    }

    const companyName = (dto.companyName || "").trim();
    const ownerName = (dto.ownerName || "").trim();
    if (companyName.length < 2) throw new BadRequestException("companyName too short");
    if (ownerName.length < 2) throw new BadRequestException("ownerName too short");

    const emailTaken = await this.prisma.company.findUnique({ where: { email } });
    if (emailTaken) throw new ConflictException("Company email already registered");

    const result = await this.prisma.$transaction(async (tx) => {
      const company = await tx.company.create({
        data: {
          companyName,
          email,
          phone: dto.phone?.trim() || "",
          status: Status.active,
          plan: Plan.free,
        },
      });
      const user = await tx.user.create({
        data: {
          companyId: company.id,
          email,
          name: ownerName,
          phone: dto.phone?.trim() || "",
          role: Role.company_admin,
          status: UserStatus.active,
          clerkId,
          lastLoginAt: new Date(),
        },
        select: {
          id: true,
          companyId: true,
          role: true,
          email: true,
          name: true,
        },
      });
      return { company, user };
    });

    return {
      companyId: result.company.id,
      userId: result.user.id,
      role: result.user.role,
      email: result.user.email,
      alreadyRegistered: false,
    };
  }

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
    return raw;
  }
}
