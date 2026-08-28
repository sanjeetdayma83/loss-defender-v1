import {
  Injectable, NotFoundException, BadRequestException, UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { tenantWhere } from "../common/utils/tenant-where";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { createHmac, timingSafeEqual, createCipheriv, createDecipheriv, randomBytes, scryptSync } from "crypto";

type MarketplaceName = "amazon" | "flipkart" | "meesho" | "shopify" | "woocommerce" | "manual";

@Injectable()
export class MarketplaceService {
  private encKey: Buffer;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    // Derive 32-byte key from CLERK secret or a dedicated env — replace with real secret manager in prod
    const secret = this.config.get<string>("clerk.secretKey") || "dev-fallback-key-change-me";
    this.encKey = scryptSync(secret, "loss-defender-v1", 32);
  }

  private encrypt(plain: string): string {
    const iv = randomBytes(16);
    const cipher = createCipheriv("aes-256-gcm", this.encKey, iv);
    const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
    const tag = cipher.getAuthTag();
    return `${iv.toString("hex")}:${tag.toString("hex")}:${enc.toString("hex")}`;
  }

  private decrypt(payload: string): string {
    const [ivHex, tagHex, dataHex] = payload.split(":");
    const decipher = createDecipheriv("aes-256-gcm", this.encKey, Buffer.from(ivHex, "hex"));
    decipher.setAuthTag(Buffer.from(tagHex, "hex"));
    return Buffer.concat([
      decipher.update(Buffer.from(dataHex, "hex")),
      decipher.final(),
    ]).toString("utf8");
  }

  async list(user: AuthUser) {
    const rows = await this.prisma.marketplaceAccount.findMany({
      where: tenantWhere(user.companyId),
      select: {
        id: true, marketplace: true, status: true, lastSyncAt: true, createdAt: true,
      },
    });
    return rows;
  }

  async connect(
    user: AuthUser,
    dto: { marketplace: MarketplaceName; accessToken: string; refreshToken?: string; webhookSecret?: string },
  ) {
    if (dto.marketplace === "manual") {
      throw new BadRequestException("Cannot connect 'manual' marketplace");
    }

    const data = {
      accessToken: this.encrypt(dto.accessToken),
      refreshToken: dto.refreshToken ? this.encrypt(dto.refreshToken) : null,
      webhookSecret: dto.webhookSecret ? this.encrypt(dto.webhookSecret) : null,
      status: "active" as const,
    };

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
        ...data,
      },
      update: data,
      select: { id: true, marketplace: true, status: true, createdAt: true },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: user.companyId,
        actorId: user.id,
        action: "marketplace.connect",
        entityType: "MarketplaceAccount",
        entityId: row.id,
        afterState: { marketplace: dto.marketplace },
      },
    });

    return row;
  }

  /**
   * Verify HMAC against RAW body bytes — never re-serialized JSON (Security Rule #3).
   */
  verifyWebhookSignature(
    rawBody: Buffer,
    signatureHeader: string | undefined,
    secret: string,
  ): boolean {
    if (!signatureHeader || !secret) return false;
    const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
    const provided = signatureHeader.replace(/^sha256=/i, "").trim();
    try {
      const a = Buffer.from(expected, "hex");
      const b = Buffer.from(provided, "hex");
      if (a.length !== b.length) return false;
      return timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }

  async handleWebhook(
    provider: string,
    rawBody: Buffer,
    signature: string | undefined,
  ) {
    const marketplace = provider.toLowerCase() as MarketplaceName;
    const accounts = await this.prisma.marketplaceAccount.findMany({
      where: { marketplace: marketplace as any, status: "active" },
    });

    // Find account whose webhook secret validates (multi-tenant webhook endpoint)
    let matched: typeof accounts[0] | null = null;
    for (const acc of accounts) {
      if (!acc.webhookSecret) continue;
      try {
        const secret = this.decrypt(acc.webhookSecret);
        if (this.verifyWebhookSignature(rawBody, signature, secret)) {
          matched = acc;
          break;
        }
      } catch {
        continue;
      }
    }

    if (!matched) {
      throw new UnauthorizedException("Invalid webhook signature");
    }

    let payload: any;
    try {
      payload = JSON.parse(rawBody.toString("utf8"));
    } catch {
      throw new BadRequestException("Invalid JSON body");
    }

    // Stub: record sync time — real SP-API / order ingest is next iteration
    await this.prisma.marketplaceAccount.update({
      where: { id: matched.id },
      data: { lastSyncAt: new Date() },
    });

    await this.prisma.auditLog.create({
      data: {
        companyId: matched.companyId,
        actorId: matched.companyId, // system
        action: "marketplace.webhook",
        entityType: "MarketplaceAccount",
        entityId: matched.id,
        afterState: { provider, event: payload?.event || payload?.type || "unknown" },
      },
    });

    return { received: true, companyId: matched.companyId };
  }
}