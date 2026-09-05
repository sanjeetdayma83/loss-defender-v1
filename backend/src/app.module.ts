import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { APP_GUARD } from "@nestjs/core";
import { ThrottlerModule, ThrottlerGuard } from "@nestjs/throttler";
import configuration from "./config/configuration";
import { PrismaModule } from "./prisma/prisma.module";
import { StorageModule } from "./storage/storage.module";
import { ClerkAuthGuard } from "./common/guards/clerk-auth.guard";
import { TenantGuard } from "./common/guards/tenant.guard";
import { RolesGuard } from "./common/guards/roles.guard";
import { PermissionsGuard } from "./common/guards/permissions.guard";
import { PlanLimitGuard } from "./common/guards/plan-limit.guard";
import { AuthModule } from "./auth/auth.module";
import { CompaniesModule } from "./companies/companies.module";
import { UsersModule } from "./users/users.module";
import { WarehousesModule } from "./warehouses/warehouses.module";
import { OrdersModule } from "./orders/orders.module";
import { ScannerModule } from "./scanner/scanner.module";
import { RecordingsModule } from "./recordings/recordings.module";
import { EvidenceModule } from "./evidence/evidence.module";
import { UploadModule } from "./upload/upload.module";
import { ClaimsModule } from "./claims/claims.module";
import { ReturnsModule } from "./returns/returns.module";
import { MarketplaceModule } from "./marketplace/marketplace.module";
import { AuditModule } from "./audit/audit.module";
import { AnalyticsModule } from "./analytics/analytics.module";
import { BillingModule } from "./billing/billing.module";
import { NotificationsModule } from "./notifications/notifications.module";
import { HealthController } from "./health.controller";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, load: [configuration] }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    PrismaModule,
    StorageModule,
    AuthModule,
    CompaniesModule,
    UsersModule,
    WarehousesModule,
    OrdersModule,
    ScannerModule,
    RecordingsModule,
    EvidenceModule,
    UploadModule,
    ClaimsModule,
    ReturnsModule,
    MarketplaceModule,
    AuditModule,
    AnalyticsModule,
    BillingModule,
    NotificationsModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: ClerkAuthGuard },
    { provide: APP_GUARD, useClass: TenantGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
    { provide: APP_GUARD, useClass: PlanLimitGuard },
  ],
})
export class AppModule {}