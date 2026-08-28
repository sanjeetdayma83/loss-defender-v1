import { Module } from "@nestjs/common";
import { RecordingsController } from "./recordings.controller";
import { RecordingsService } from "./recordings.service";
import { EvidenceModule } from "../evidence/evidence.module";

@Module({
  imports: [EvidenceModule],
  controllers: [RecordingsController],
  providers: [RecordingsService],
  exports: [RecordingsService],
})
export class RecordingsModule {}