import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ForbiddenException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { createHash, randomBytes } from "crypto";
import { AuthUser } from "../common/decorators/current-user.decorator";

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService) {}

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
