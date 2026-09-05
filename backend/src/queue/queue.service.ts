import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Queue, Worker, JobsOptions } from "bullmq";
import IORedis from "ioredis";

/** Optional queue. Missing/unreachable Redis = disabled, no retry spam. */
@Injectable()
export class QueueService implements OnModuleInit, OnModuleDestroy {
  private readonly log = new Logger(QueueService.name);
  private connection: IORedis | null = null;
  private notifyQueue: Queue | null = null;
  private evidenceQueue: Queue | null = null;
  private workers: Worker[] = [];
  enabled = false;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    const url =
      this.config.get<string>("redis.url") ||
      this.config.get<string>("REDIS_URL") ||
      process.env.REDIS_URL;

    if (!url || url.includes("localhost") || url.includes("127.0.0.1")) {
      // Local default without real Redis → stay off unless FORCE_REDIS=true
      if (process.env.FORCE_REDIS !== "true") {
        this.log.warn("Queues disabled (no Redis / local URL without FORCE_REDIS=true)");
        return;
      }
    }
    if (!url) {
      this.log.warn("REDIS_URL not set — queues disabled");
      return;
    }

    try {
      this.connection = new IORedis(url, {
        maxRetriesPerRequest: null,
        lazyConnect: true,
        enableOfflineQueue: false,
        showFriendlyErrorStack: false,
        retryStrategy: () => null, // do not reconnect loop
      });
      this.connection.on("error", (err) => {
        this.log.warn(`Redis error (queues off): ${err.message}`);
      });

      await Promise.race([
        this.connection.connect(),
        new Promise((_, rej) =>
          setTimeout(() => rej(new Error("Redis connect timeout")), 2000),
        ),
      ]);

      this.notifyQueue = new Queue("notifications", { connection: this.connection });
      this.evidenceQueue = new Queue("evidence", { connection: this.connection });
      this.workers.push(
        new Worker("notifications", async (job) => {
          this.log.log(`notify job ${job.id}`);
        }, { connection: this.connection }),
        new Worker("evidence", async (job) => {
          this.log.log(`evidence job ${job.id}`);
        }, { connection: this.connection }),
      );
      this.enabled = true;
      this.log.log("BullMQ queues ready");
    } catch (e: any) {
      this.log.warn(`Redis unavailable — queues disabled: ${e?.message || e}`);
      try { this.connection?.disconnect(); } catch { /* ignore */ }
      this.connection = null;
      this.enabled = false;
    }
  }

  async onModuleDestroy() {
    for (const w of this.workers) await w.close().catch(() => {});
    await this.notifyQueue?.close().catch(() => {});
    await this.evidenceQueue?.close().catch(() => {});
    try { this.connection?.disconnect(); } catch { /* ignore */ }
  }

  async enqueueNotify(data: Record<string, unknown>, opts?: JobsOptions) {
    if (!this.enabled || !this.notifyQueue) return null;
    return this.notifyQueue.add("deliver", data, opts);
  }

  async enqueueEvidence(data: Record<string, unknown>, opts?: JobsOptions) {
    if (!this.enabled || !this.evidenceQueue) return null;
    return this.evidenceQueue.add("process", data, opts);
  }
}