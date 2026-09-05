import { SetMetadata } from "@nestjs/common";
import { PLAN_LIMIT_KEY } from "../guards/plan-limit.guard";

export const PlanLimit = (type: "users" | "warehouses") =>
  SetMetadata(PLAN_LIMIT_KEY, type);