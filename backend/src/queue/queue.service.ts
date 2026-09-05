import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Queue, Worker, JobsOptions } from "bullmq";
import IORedis from "ioredis";

/**
 * Optional queue. If REDIS_URL missing/unreachable, jobs are no-ops (logged).
 */
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
    const url = this.config.get<string>("REDIS_URL") || process.env.REDIS_URL;
    if (!url) {
      this.log.warn("REDIS_URL not set — queues disabled");
      return;
    }
    try {
      this.connection = new IORedis(url, { maxRetriesPerRequest: null, lazyConnect: true });
      await this.connection.connect();
      this.notifyQueue = new Queue("notifications", { connection: this.connection });
      this.evidenceQueue = new Queue("evidence", { connection: this.connection });

      this.workers.push(
        new Worker(
          "notifications",
          async (job) => {
            this.log.log(`notify job ${job.id}: ${JSON.stringify(job.data)}`);
            // Future: email/FCM providers
          },
          { connection: this.connection },
        ),
        new Worker(
          "evidence",
          async (job) => {
            this.log.log(`evidence job ${job.id}: ${JSON.stringify(job.data)}`);
            // Future: FFmpeg frame extract
          },
          { connection: this.connection },
        ),
      );
      this.enabled = true;
      this.log.log("BullMQ queues ready");
    } catch (e) {
      this.log.warn(`Redis unavailable — queues disabled: ${e}`);
      this.enabled = false;
    }
  }

  async onModuleDestroy() {
    for (const w of this.workers) await w.close().catch(() => {});
    await this.notifyQueue?.close().catch(() => {});
    await this.evidenceQueue?.close().catch(() => {});
    this.connection?.disconnect();
  }

  async enqueueNotify(data: Record<string, unknown>, opts?: JobsOptions) {
    if (!this.enabled || !this.notifyQueue) {
      this.log.debug(`notify skipped (queue off): ${JSON.stringify(data)}`);
      return null;
    }
    return this.notifyQueue.add("deliver", data, opts);
  }

  async enqueueEvidence(data: Record<string, unknown>, opts?: JobsOptions) {
    if (!this.enabled || !this.evidenceQueue) {
      this.log.debug(`evidence skipped (queue off): ${JSON.stringify(data)}`);
      return null;
    }
    return this.evidenceQueue.add("process", data, opts);
  }
}