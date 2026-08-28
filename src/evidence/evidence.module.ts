import { Module } from "@nestjs/common";
import { EvidenceController } from "./evidence.controller";
import { EvidenceService } from "./evidence.service";
import { UploadModule } from "../upload/upload.module";

@Module({
  imports: [UploadModule],
  controllers: [EvidenceController],
  providers: [EvidenceService],
  exports: [EvidenceService],
})
export class EvidenceModule {}