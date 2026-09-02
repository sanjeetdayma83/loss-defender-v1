import { NestFactory } from "@nestjs/core";
import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import helmet from "helmet";
import compression from "compression";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });

  const config = app.get(ConfigService);
  const port = config.get<number>("port") ?? 3000;
  const apiVersion = config.get<string>("apiVersion") ?? "v1";

  app.use(helmet());
  app.use(compression());
  app.enableCors({ origin: true, credentials: true });
  app.setGlobalPrefix(`api/${apiVersion}`);
  

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  if (config.get("nodeEnv") !== "production") {
    const swaggerConfig = new DocumentBuilder()
      .setTitle("LOSS DEFENDER V1 API")
      .setDescription("Video Management System for warehouse packing evidence")
      .setVersion("1.0")
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup("docs", app, document);
  }

  await app.listen(port);
  console.log(`LOSS DEFENDER V1 API running on :${port}/api/${apiVersion}`);
}
bootstrap();
