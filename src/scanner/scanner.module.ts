import { Module } from "@nestjs/common";
import { ScannerController } from "./scanner.controller";
import { ScannerService } from "./scanner.service";
import { OrdersModule } from "../orders/orders.module";

@Module({
  imports: [OrdersModule],
  controllers: [ScannerController],
  providers: [ScannerService],
  exports: [ScannerService],
})
export class ScannerModule {}