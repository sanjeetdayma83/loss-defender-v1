import {
  Injectable, BadRequestException, UnauthorizedException,
} from "@nestjs/common";
import { PrismaService } from "../prisma/prisma.service";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { createHmac, timingSafeEqual } from "crypto";

@Injectable()
export class MarketplaceService {
  constructor(private readonly prisma: PrismaService) {}

  async list(user: AuthUser) {
    return this.listAccounts(user);
  }

  async listAccounts(user: AuthUser) {
    return this.prisma.marketplaceAccount.findMany({
      where: { companyId: user.companyId },
      select: {
        id: true,
        marketplace: true,
        status: true,
        lastSyncAt: true,
        createdAt: true,
      },
    });
  }

  async connect(
    user: AuthUser,
    dto: {
      marketplace: string;
      accessToken: string;
      refreshToken?: string;
      webhookSecret?: string;
    },
  ) {
    if (dto.marketplace === "manual") {
      throw new BadRequestException("Cannot connect manual marketplace");
    }
    const row = await this.prisma.marketplaceAccount.upsert({
      where: {
        companyId_marketplace: {
          companyId: user.companyId,
          marketplace: dto.marketplace as any,
        },
      },
      create: {
        companyId: user.companyId,
        marketplace: dto.marketplace as any,
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        webhookSecret: dto.webhookSecret,
        status: "active",
      },
      update: {
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        webhookSecret: dto.webhookSecret,
        status: "active",
      },
      select: { id: true, marketplace: true, status: true, createdAt: true },
    });
    return row;
  }

  /**
   * Doc §12 #3: verify HMAC against *raw body bytes*, never re-serialized JSON.
   */
  async handleWebhook(
    provider: string,
    rawBody: Buffer,
    signature: string | undefined,
  ) {
    const allowed = ["amazon", "flipkart", "meesho", "shopify", "woocommerce"];
    if (!allowed.includes(provider)) {
      throw new BadRequestException(`Unknown provider: ${provider}`);
    }

    const account = await this.prisma.marketplaceAccount.findFirst({
      where: { marketplace: provider as any, status: "active" },
      orderBy: { createdAt: "desc" },
    });

    if (!account?.webhookSecret) {
      throw new UnauthorizedException(
        "No webhook secret configured for this provider",
      );
    }

    if (!signature) {
      throw new UnauthorizedException("Missing webhook signature");
    }

    const expected = createHmac("sha256", account.webhookSecret)
      .update(rawBody)
      .digest("hex");

    const a = Buffer.from(expected);
    const b = Buffer.from(signature.replace(/^sha256=/i, ""));
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new UnauthorizedException("Invalid webhook signature");
    }

    // Parse only AFTER signature check
    let payload: any = {};
    try {
      payload = JSON.parse(rawBody.toString("utf8"));
    } catch {
      throw new BadRequestException("Invalid JSON body");
    }

    await this.prisma.marketplaceAccount.update({
      where: { id: account.id },
      data: { lastSyncAt: new Date() },
    });

    return {
      received: true,
      provider,
      event: payload?.event || payload?.type || "unknown",
      accountId: account.id,
    };
  }
}