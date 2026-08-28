import { Injectable, BadRequestException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import {
  S3Client,
  CreateMultipartUploadCommand,
  UploadPartCommand,
  CompleteMultipartUploadCommand,
  AbortMultipartUploadCommand,
  PutObjectCommand,
  GetObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { AuthUser } from "../common/decorators/current-user.decorator";
import { randomUUID } from "crypto";

@Injectable()
export class UploadService {
  private client: S3Client;
  private bucket: string;
  private ttl: number;

  constructor(private readonly config: ConfigService) {
    const endpoint = this.config.get<string>("b2.endpoint");
    this.bucket = this.config.get<string>("b2.bucket") || "";
    this.ttl = this.config.get<number>("b2.signedUrlTtl") || 900;

    this.client = new S3Client({
      endpoint,
      region: "us-west-002",
      credentials: {
        accessKeyId: this.config.get<string>("b2.keyId") || "",
        secretAccessKey: this.config.get<string>("b2.applicationKey") || "",
      },
      forcePathStyle: true,
    });
  }

  /** Init multipart upload — returns uploadId + key under company prefix. */
  async initMultipart(user: AuthUser, opts: { filename: string; contentType: string; prefix?: string }) {
    if (!this.bucket) throw new BadRequestException("B2 bucket not configured");

    const safeName = opts.filename.replace(/[^a-zA-Z0-9._-]/g, "_");
    const key = `${user.companyId}/${opts.prefix || "media"}/${randomUUID()}-${safeName}`;

    const cmd = new CreateMultipartUploadCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: opts.contentType,
    });
    const res = await this.client.send(cmd);
    if (!res.UploadId) throw new BadRequestException("Failed to init multipart upload");

    return { uploadId: res.UploadId, key, bucket: this.bucket };
  }

  /** Presigned URL for a single part (client PUTs bytes directly to B2). */
  async presignPart(key: string, uploadId: string, partNumber: number) {
    if (partNumber < 1 || partNumber > 10000) {
      throw new BadRequestException("partNumber must be 1–10000");
    }
    const cmd = new UploadPartCommand({
      Bucket: this.bucket,
      Key: key,
      UploadId: uploadId,
      PartNumber: partNumber,
    });
    const url = await getSignedUrl(this.client, cmd, { expiresIn: this.ttl });
    return { url, partNumber, expiresIn: this.ttl };
  }

  async completeMultipart(
    key: string,
    uploadId: string,
    parts: { partNumber: number; etag: string }[],
  ) {
    const cmd = new CompleteMultipartUploadCommand({
      Bucket: this.bucket,
      Key: key,
      UploadId: uploadId,
      MultipartUpload: {
        Parts: parts
          .sort((a, b) => a.partNumber - b.partNumber)
          .map((p) => ({ PartNumber: p.partNumber, ETag: p.etag })),
      },
    });
    const res = await this.client.send(cmd);
    return { key, location: res.Location, etag: res.ETag };
  }

  async abortMultipart(key: string, uploadId: string) {
    await this.client.send(
      new AbortMultipartUploadCommand({
        Bucket: this.bucket,
        Key: key,
        UploadId: uploadId,
      }),
    );
    return { aborted: true };
  }

  /** Short-lived signed GET for private media (5–15 min TTL). */
  async signedDownloadUrl(key: string) {
    const cmd = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    const url = await getSignedUrl(this.client, cmd, { expiresIn: this.ttl });
    return { url, expiresIn: this.ttl };
  }

  async signedPutUrl(user: AuthUser, filename: string, contentType: string, prefix?: string) {
    const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, "_");
    const key = `${user.companyId}/${prefix || "media"}/${randomUUID()}-${safeName}`;
    const cmd = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    const url = await getSignedUrl(this.client, cmd, { expiresIn: this.ttl });
    return { url, key, expiresIn: this.ttl };
  }
}