import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private client: S3Client | null = null;
  private bucket: string | null = null;
  private ttl: number;

  constructor(private readonly config: ConfigService) {
    const keyId = this.config.get<string>("b2.keyId");
    const appKey = this.config.get<string>("b2.applicationKey");
    const endpoint = this.config.get<string>("b2.endpoint");
    this.bucket = this.config.get<string>("b2.bucket") || null;
    this.ttl = this.config.get<number>("b2.signedUrlTtl") || 900;

    if (keyId && appKey && endpoint && this.bucket && !keyId.includes("xxx")) {
      this.client = new S3Client({
        endpoint,
        region: "us-west-002",
        credentials: { accessKeyId: keyId, secretAccessKey: appKey },
        forcePathStyle: true,
      });
      this.logger.log("B2 storage client configured");
    } else {
      this.logger.warn("B2 keys not configured — signed URLs will be null (dev mode)");
    }
  }

  isConfigured(): boolean {
    return !!this.client && !!this.bucket;
  }

  async getUploadSignedUrl(key: string, contentType = "video/mp4"): Promise<string | null> {
    if (!this.client || !this.bucket) return null;
    const cmd = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    return getSignedUrl(this.client, cmd, { expiresIn: this.ttl });
  }

  async getDownloadSignedUrl(key: string): Promise<string | null> {
    if (!this.client || !this.bucket) return null;
    const cmd = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    return getSignedUrl(this.client, cmd, { expiresIn: this.ttl });
  }

  async createMultipart(key: string, contentType = "video/mp4") {
    if (!this.client || !this.bucket) {
      return { uploadId: `dev-${Date.now()}`, key, configured: false };
    }
    const out = await this.client.send(
      new CreateMultipartUploadCommand({
        Bucket: this.bucket,
        Key: key,
        ContentType: contentType,
      }),
    );
    return { uploadId: out.UploadId!, key, configured: true };
  }

  async signPart(key: string, uploadId: string, partNumber: number) {
    if (!this.client || !this.bucket) return null;
    const cmd = new UploadPartCommand({
      Bucket: this.bucket,
      Key: key,
      UploadId: uploadId,
      PartNumber: partNumber,
    });
    return getSignedUrl(this.client, cmd, { expiresIn: this.ttl });
  }

  async completeMultipart(
    key: string,
    uploadId: string,
    parts: Array<{ ETag: string; PartNumber: number }>,
  ) {
    if (!this.client || !this.bucket) return { ok: true, dev: true };
    await this.client.send(
      new CompleteMultipartUploadCommand({
        Bucket: this.bucket,
        Key: key,
        UploadId: uploadId,
        MultipartUpload: { Parts: parts },
      }),
    );
    return { ok: true };
  }

  async abortMultipart(key: string, uploadId: string) {
    if (!this.client || !this.bucket) return;
    await this.client.send(
      new AbortMultipartUploadCommand({
        Bucket: this.bucket,
        Key: key,
        UploadId: uploadId,
      }),
    );
  }
}
