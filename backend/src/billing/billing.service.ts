import {
  Injectable, BadRequestException, UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaService } from "../prisma/prisma.service";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { createHmac, timingSafeEqual } from "crypto";

const PLAN_QUOTAS: Record<string, { users: number; warehouses: number; storageBytes: bigint; priceInr: number }> = {
  free: { users: 3, warehouses: 1, storageBytes: 5368709120n, priceInr: 0 },
  starter: { users: 10, warehouses: 2, storageBytes: 53687091200n, priceInr: 1999 },
  professional: { users: 50, warehouses: 5, storageBytes: 536870912000n, priceInr: 4999 },
  enterprise: { users: 99999, warehouses: 99999, storageBytes: 2199023255552n, priceInr: 0 },
};

function publicQuotas(plan: string) {
  const q = PLAN_QUOTAS[plan] || PLAN_QUOTAS.free;
  return {
    users: q.users,
    warehouses: q.warehouses,
    storageGb: Number(q.storageBytes / 1073741824n),
    priceInr: q.priceInr,
  };
}

@Injectable()
export class BillingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async getSubscription(user: AuthUser) {
    const sub = await this.prisma.billingSubscription.findUnique({
      where: { companyId: user.companyId },
    });
    const company = await this.prisma.company.findFirst({
      where: { id: user.companyId },
      select: { plan: true, storageUsed: true, storageQuota: true },
    });
    const plan = company?.plan || "free";
    return {
      subscription: sub,
      plan,
      quotas: publicQuotas(plan),
      storageUsed: company?.storageUsed?.toString() ?? "0",
      storageQuota: company?.storageQuota?.toString() ?? "0",
    };
  }

  async subscribe(
    user: AuthUser,
    dto: { plan: "starter" | "professional" | "enterprise"; razorpaySubId: string },
  ) {
    if (!PLAN_QUOTAS[dto.plan]) throw new BadRequestException("Invalid plan");
    const now = new Date();
    const periodEnd = new Date(now);
    periodEnd.setMonth(periodEnd.getMonth() + 1);
    const sub = await this.prisma.billingSubscription.upsert({
      where: { companyId: user.companyId },
      create: {
        companyId: user.companyId,
        razorpaySubId: dto.razorpaySubId,
        plan: dto.plan as any,
        status: "active",
        currentPeriodStart: now,
        currentPeriodEnd: periodEnd,
      },
      update: {
        razorpaySubId: dto.razorpaySubId,
        plan: dto.plan as any,
        status: "active",
        currentPeriodStart: now,
        currentPeriodEnd: periodEnd,
      },
    });
    await this.prisma.company.update({
      where: { id: user.companyId },
      data: {
        plan: dto.plan as any,
        storageQuota: PLAN_QUOTAS[dto.plan].storageBytes,
      },
    });
    return sub;
  }

  getPlans() {
    return Object.keys(PLAN_QUOTAS).map((id) => ({ id, ...publicQuotas(id) }));
  }

  verifyRazorpaySignature(rawBody: Buffer, signature: string | undefined): boolean {
    const secret = this.config.get<string>("razorpay.keySecret");
    if (!secret || !signature) return false;
    const expected = createHmac("sha256", secret).update(rawBody).digest("hex");
    try {
      const a = Buffer.from(expected);
      const b = Buffer.from(signature);
      if (a.length !== b.length) return false;
      return timingSafeEqual(a, b);
    } catch {
      return false;
    }
  }

  async handleRazorpayWebhook(rawBody: Buffer, signature: string | undefined) {
    if (!this.verifyRazorpaySignature(rawBody, signature)) {
      throw new UnauthorizedException("Invalid Razorpay signature");
    }
    const payload = JSON.parse(rawBody.toString("utf8"));
    return { received: true, event: payload?.event };
  }
}