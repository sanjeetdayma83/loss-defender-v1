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

  getPlans() {
    return Object.keys(PLAN_QUOTAS).map((plan) => ({
      plan,
      ...publicQuotas(plan),
    }));
  }

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

  /**
   * Creates/updates a *pending* subscription only.
   * Company.plan is NEVER activated from the client — only via Razorpay webhook.
   */
  async subscribe(
    user: AuthUser,
    dto: { plan: "starter" | "professional" | "enterprise"; razorpaySubId?: string },
  ) {
    if (!PLAN_QUOTAS[dto.plan]) throw new BadRequestException("Invalid plan");
    const now = new Date();
    const periodEnd = new Date(now);
    periodEnd.setMonth(periodEnd.getMonth() + 1);
    const razorpaySubId = dto.razorpaySubId?.trim() || `pending_${user.companyId}_${Date.now()}`;

    const sub = await this.prisma.billingSubscription.upsert({
      where: { companyId: user.companyId },
      create: {
        companyId: user.companyId,
        razorpaySubId,
        plan: dto.plan as any,
        status: "pending",
        currentPeriodStart: now,
        currentPeriodEnd: periodEnd,
      },
      update: {
        razorpaySubId,
        plan: dto.plan as any,
        status: "pending",
        currentPeriodStart: now,
        currentPeriodEnd: periodEnd,
      },
    });
    // Do NOT update company.plan here
    return {
      subscription: sub,
      message: "Subscription pending payment confirmation via Razorpay webhook",
    };
  }

  verifyRazorpaySignature(rawBody: Buffer, signature: string | undefined): boolean {
    const secret = this.config.get<string>("razorpay.keySecret")
      || this.config.get<string>("RAZORPAY_KEY_SECRET");
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

  /** Webhook-only plan activation */
  async handleRazorpayWebhook(rawBody: Buffer, signature: string | undefined) {
    if (!this.verifyRazorpaySignature(rawBody, signature)) {
      throw new UnauthorizedException("Invalid Razorpay signature");
    }
    const payload = JSON.parse(rawBody.toString("utf8"));
    const event = payload?.event as string | undefined;

    // Activate on subscription.activated / charged
    if (
      event === "subscription.activated" ||
      event === "subscription.charged" ||
      event === "subscription.completed"
    ) {
      const rzSubId = payload?.payload?.subscription?.entity?.id
        || payload?.payload?.subscription?.id
        || payload?.subscription?.id;
      const notesPlan = payload?.payload?.subscription?.entity?.notes?.plan
        || payload?.payload?.payment?.entity?.notes?.plan;

      if (rzSubId) {
        const sub = await this.prisma.billingSubscription.findFirst({
          where: { razorpaySubId: String(rzSubId) },
        });
        if (sub) {
          const plan = (notesPlan || sub.plan) as any;
          const quota = PLAN_QUOTAS[plan] || PLAN_QUOTAS.free;
          await this.prisma.$transaction([
            this.prisma.billingSubscription.update({
              where: { id: sub.id },
              data: { status: "active", plan },
            }),
            this.prisma.company.update({
              where: { id: sub.companyId },
              data: {
                plan,
                storageQuota: quota.storageBytes,
              },
            }),
          ]);
        }
      }
    }

    if (event === "subscription.cancelled" || event === "subscription.halted") {
      const rzSubId = payload?.payload?.subscription?.entity?.id;
      if (rzSubId) {
        const sub = await this.prisma.billingSubscription.findFirst({
          where: { razorpaySubId: String(rzSubId) },
        });
        if (sub) {
          await this.prisma.billingSubscription.update({
            where: { id: sub.id },
            data: { status: "cancelled" },
          });
        }
      }
    }

    return { received: true, event };
  }
}