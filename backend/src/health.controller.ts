import { Controller, Get } from "@nestjs/common";
import { Public } from "./common/decorators/public.decorator";

@Controller("health")
export class HealthController {
  @Public()
  @Get()
  check() {
    return {
      success: true,
      data: {
        status: "ok",
        service: "loss-defender-v1",
        timestamp: new Date().toISOString(),
      },
      error: null,
    };
  }
}
