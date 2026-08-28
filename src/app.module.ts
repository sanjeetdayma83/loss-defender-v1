import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { APP_GUARD } from "@nestjs/core";
import { ThrottlerModule, ThrottlerGuard } from "@nestjs/throttler";
import configuration from "./config/configuration";
import { PrismaModule } from "./prisma/prisma.module";
import { ClerkAuthGuard } from "./common/guards/clerk-auth.guard";
import { TenantGuard } from "./common/guards/tenant.guard";
import { RolesGuard } from "./common/guards/roles.guard";
import { AuthModule } from "./auth/auth.module";
import { CompaniesModule } from "./companies/companies.module";
import { WarehousesModule } from "./warehouses/warehouses.module";
import { UsersModule } from "./users/users.module";
import { OrdersModule } from "./orders/orders.module";
import { ScannerModule } from "./scanner/scanner.module";
import { UploadModule } from "./upload/upload.module";
import { EvidenceModule } from "./evidence/evidence.module";
import { RecordingsModule } from "./recordings/recordings.module";
import { ClaimsModule } from "./claims/claims.module";
import { ReturnsModule } from "./returns/returns.module";
import { HealthController } from "./health.controller";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    PrismaModule,
    AuthModule,
    CompaniesModule,
    WarehousesModule,
    UsersModule,
    OrdersModule,
    ScannerModule,
    UploadModule,
    EvidenceModule,
    RecordingsModule,
    ClaimsModule,
    ReturnsModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: ClerkAuthGuard },
    { provide: APP_GUARD, useClass: TenantGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}